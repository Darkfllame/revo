const std = @import("std");

const VERSION = "0.0.0";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //
    // feature flags
    //
    const features_str = b.option([]const u8, "features", "available: isocline, lsp") orelse "isocline,lsp";
    // TODO: make it be in a struct or something
    const have_isocline = hasFeature(features_str, "isocline");
    const have_lsp = hasFeature(features_str, "lsp");

    const build_options = b.addOptions();
    build_options.addOption(bool, "isocline", have_isocline);
    build_options.addOption([]const u8, "version", VERSION);
    build_options.addOption(bool, "lsp_enabled", have_lsp);

    const test_filters = b.option(
        []const []const u8,
        "test-filter",
        "only run tests within the arr",
    ) orelse &.{};

    const is_freestanding = target.result.os.tag == .freestanding;

    //
    // modules
    //
    const vm_mod = b.addModule("vm", .{
        .root_source_file = b.path("src/vm/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const revo_mod = b.addModule("revo", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const c_mod = b.addModule("c", .{
        .root_source_file = b.path("src/c/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const all_mods = [_]*std.Build.Module{ vm_mod, revo_mod, c_mod };
    const imports = [_]std.Build.Module.Import{
        .{ .name = "revo", .module = revo_mod },
        .{ .name = "vm", .module = vm_mod },
        .{ .name = "c", .module = c_mod },
    };
    for (all_mods) |mod|
        for (imports) |imp|
            mod.addImport(imp.name, imp.module);

    //
    // main exe
    //
    const exe_root = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = !is_freestanding,
        .imports = &imports,
    });
    if (!is_freestanding) {
        if (have_isocline) add_isocline(exe_root, b);
        exe_root.addOptions("build_options", build_options);
    }
    const lsp_mod = lspModule(b, target, optimize, revo_mod, &imports, have_lsp);
    exe_root.addImport("lsp_main", lsp_mod);

    const exe = b.addExecutable(.{ .name = "revo", .root_module = exe_root });
    if (optimize == .Debug) exe.lto = .none;
    exe.rdynamic = true;

    const install_exe = b.addInstallArtifact(exe, .{});
    b.getInstallStep().dependOn(&install_exe.step);

    //
    // run step
    //
    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    b.step("run", "run the cli").dependOn(&run_cmd.step);

    //
    // erevo library & header
    //
    const erevo_mod = b.addModule("erevo", .{
        .root_source_file = b.path("src/c/erevo.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &imports,
    });

    const lib = b.addLibrary(.{
        .name = "erevo",
        .root_module = erevo_mod,
    });

    const write_files = b.addWriteFiles();
    const bindings = @import("src/c/bindings.zig");
    const header_data = bindings.data(b.allocator) catch |err| {
        std.debug.print("failed to autogen header: {any}\n", .{err});
        std.process.exit(1);
    };
    const header_path = write_files.add("revo.h", header_data.items);

    const lib_step = b.step("lib", "build the erevo library");
    lib_step.dependOn(&b.addInstallArtifact(lib, .{}).step);
    lib_step.dependOn(&b.addInstallFile(header_path, "include/revo.h").step);

    const vm_test = b.addTest(.{ .root_module = vm_mod, .filters = test_filters });
    const revo_test = b.addTest(.{ .root_module = revo_mod, .filters = test_filters });
    const exe_test = b.addTest(.{ .root_module = exe_root, .filters = test_filters });
    const c_test = b.addTest(.{ .root_module = c_mod, .filters = test_filters });
    const lsp_test = b.addTest(.{ .root_module = lsp_mod, .filters = test_filters });

    //
    // check step
    //
    const check_step = b.step("check", "type-check without codegen or linking");
    check_step.dependOn(&vm_test.step);
    check_step.dependOn(&revo_test.step);
    check_step.dependOn(&exe_test.step);
    check_step.dependOn(&c_test.step);
    check_step.dependOn(&lsp_test.step);

    //
    // tests
    //
    const test_step = b.step("test", "run all tests");

    const test_vm_step = b.step("test-vm", "test only the vm module");
    test_vm_step.dependOn(&b.addRunArtifact(vm_test).step);

    const test_revo_step = b.step("test-revo", "test only the revo module");
    test_revo_step.dependOn(&b.addRunArtifact(revo_test).step);

    const test_exe_step = b.step("test-exe", "test only the exe root");
    test_exe_step.dependOn(&b.addRunArtifact(exe_test).step);

    test_step.dependOn(test_vm_step);
    test_step.dependOn(test_revo_step);
    test_step.dependOn(test_exe_step);

    //
    // c test suite
    //
    const test_c_step = b.step("test-c", "run c api tests");
    test_c_step.dependOn(lib_step);

    const c_test_bin = b.addSystemCommand(&.{
        "cc",                "-std=c99",               "-Wall",                  "-Wextra",
        "-Izig-out/include", "src/c/tests.c",          "zig-out/lib/liberevo.a", "-lm",
        "-o",                ".zig-cache/revo-c-test",
    });
    test_c_step.dependOn(&c_test_bin.step);

    const c_test_run = b.addSystemCommand(&.{".zig-cache/revo-c-test"});
    c_test_run.step.dependOn(&c_test_bin.step);
    test_c_step.dependOn(&c_test_run.step);

    //
    // releases
    //
    const release_targets: []const []const u8 = &.{
        "x86_64-linux-musl",
        // "aarch64-linux-musl",
        // "x86_64-macos",
        "aarch64-macos",
        "x86_64-windows",
    };

    // TODO: make it clean the output dir without running an os command
    const release_step = b.step("release", "build release binaries for all targets");

    for (release_targets) |target_str| {
        const release_target = b.resolveTargetQuery(
            std.Target.Query.parse(.{ .arch_os_abi = target_str }) catch |err| {
                std.debug.panic("invalid target '{s}': {}", .{ target_str, err });
            },
        );

        const release_mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = release_target,
            .optimize = .ReleaseFast,
            .link_libc = true,
            .imports = &imports,
        });
        if (have_isocline) add_isocline(release_mod, b);
        release_mod.addOptions("build_options", build_options);
        release_mod.addImport("lsp_main", lspModule(b, release_target, .ReleaseFast, revo_mod, &imports, have_lsp));

        const release_exe = b.addExecutable(.{
            .name = binName(b, target_str),
            .root_module = release_mod,
        });
        release_exe.rdynamic = true;

        const install = b.addInstallArtifact(release_exe, .{
            .dest_dir = .{ .override = .{ .custom = "release" } },
        });
        release_step.dependOn(&install.step);
    }

    //
    // lsp
    //
    if (b.lazyDependency("lsp_kit", .{})) |lsp_kit_dep| {
        const lsp_kit_mod = lsp_kit_dep.module("lsp");

        const revolt_root = b.createModule(.{
            .root_source_file = b.path("src/lsp/server.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &(imports ++ [_]std.Build.Module.Import{
                .{ .name = "lsp", .module = lsp_kit_mod },
            }),
        });

        const revolt = b.addExecutable(.{ .name = "revolt", .root_module = revolt_root });
        const install_revolt = b.addInstallArtifact(revolt, .{});

        check_step.dependOn(&b.addTest(.{ .root_module = revolt_root, .filters = test_filters }).step);

        const revolt_step = b.step("lsp", "build the lsp");
        revolt_step.dependOn(&install_revolt.step);
    }
}

/// returns the real lsp server module if available and enabled, otherwise a noop stub
fn lspModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    revo_mod: *std.Build.Module,
    imports: []const std.Build.Module.Import,
    enabled: bool,
) *std.Build.Module {
    if (enabled) {
        if (b.lazyDependency("lsp_kit", .{})) |lsp_kit_dep| {
            const lsp_mod = lsp_kit_dep.module("lsp");
            const server_mod = b.createModule(.{ .root_source_file = b.path("src/lsp/server.zig"), .target = target, .optimize = optimize, .imports = imports });
            server_mod.addImport("lsp", lsp_mod);
            return server_mod;
        }
        // std.debug.print("warning: lsp_kit not fetched, lsp won't be bundled. run zig build --fetch if you need it\n", .{});
    }
    const noop = b.createModule(.{
        .root_source_file = b.path("src/lsp/noop.zig"),
        .target = target,
        .optimize = optimize,
    });
    noop.addImport("revo", revo_mod);
    return noop;
}

/// for release bin names
fn binName(b: *std.Build, triple: []const u8) []const u8 {
    const epoch_secs = std.time.epoch.EpochSeconds{
        .secs = @intCast(std.Io.Clock.real.now(b.graph.io).toSeconds()),
    };
    const year_day = epoch_secs.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();
    const date_str = b.fmt("{d}{d:0>2}{d:0>2}", .{
        year_day.year,
        month_day.month.numeric(),
        month_day.day_index + 1,
    });
    // nightly
    return b.fmt("revo-nightly-{s}-{s}", .{ triple, date_str });
    // release
    // return b.fmt("revo-{s}-{s}", .{ VERSION, triple });
}

fn hasFeature(features: []const u8, name: []const u8) bool {
    if (features.len == 0) return false;
    var it = std.mem.splitScalar(u8, features, ',');
    while (it.next()) |token| {
        if (std.mem.eql(u8, token, name)) return true;
    }
    return false;
}

fn add_isocline(mod: *std.Build.Module, b: *std.Build) void {
    mod.addCSourceFile(.{
        .file = b.path("deps/isocline/src/isocline.c"),
        .flags = &.{},
    });
    mod.addIncludePath(b.path("deps/isocline/include"));
}
