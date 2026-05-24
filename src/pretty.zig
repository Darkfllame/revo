// for colored printing

const std = @import("std");

/// should be fine as a global
pub var supports_color: bool = true;

pub const Color = enum {
    reset,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    bold,
    dim,

    pub fn code(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[0m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
            .magenta => "\x1b[35m",
            .cyan => "\x1b[36m",
            .bold => "\x1b[1m",
            .dim => "\x1b[2m",
        };
    }
};

/// https://no-color.org/, https://bixense.com/clicolors/
pub fn isColorSupported(env: std.process.Environ.Map) bool {
    if (env.contains("NO_COLOR")) return false;
    if (env.contains("CLICOLOR_FORCE")) return true;
    if (env.contains("FORCE_COLOR")) return true;

    const stdout = std.Io.File.stdout();
    if (!stdout.isTty()) return false;

    if (std.process.hasEnvVarConstant("TERM")) {
        const term = std.process.getEnvVar(std.heap.page_allocator, "TERM") catch return false;
        defer std.heap.page_allocator.free(term);
        if (std.mem.eql(u8, term, "dumb")) return false;
    }

    return true;
}

/// single style
pub fn printColored(alloc: std.mem.Allocator, writer: *std.Io.Writer, color: Color, comptime fmt: []const u8, args: anytype) !void {
    _ = alloc;
    if (supports_color) try writer.writeAll(color.code());
    try writer.print(fmt, args);
    if (supports_color) try writer.writeAll(Color.reset.code());
    try writer.flush();
}

/// multiple styles, like .bold, .red
pub fn printStyled(alloc: std.mem.Allocator, writer: *std.Io.Writer, styles: []const Color, comptime fmt: []const u8, args: anytype) !void {
    _ = alloc;
    if (supports_color) {
        for (styles) |style| try writer.writeAll(style.code());
    }
    try writer.print(fmt, args);
    if (supports_color) try writer.writeAll(Color.reset.code());
    try writer.flush();
}

pub fn printError(alloc: std.mem.Allocator, writer: *std.Io.Writer, comptime fmt: []const u8, args: anytype) !void {
    try printStyled(alloc, writer, &.{ Color.bold, Color.red }, "error", .{});
    try writer.writeAll(": ");
    try writer.print(fmt, args);
    try writer.writeAll("\n");
    try writer.flush();
}

pub fn printErrorName(alloc: std.mem.Allocator, writer: *std.Io.Writer, err: anyerror) !void {
    try printStyled(alloc, writer, &.{ Color.bold, Color.red }, "error", .{});
    try writer.writeAll(": ");
    try writer.writeAll(@errorName(err));
    try writer.writeAll("\n");
    try writer.flush();
}

pub fn printWarning(alloc: std.mem.Allocator, writer: *std.Io.Writer, comptime fmt: []const u8, args: anytype) !void {
    try printStyled(alloc, writer, &.{Color.yellow}, "warning", .{});
    try writer.writeAll(": ");
    try writer.print(fmt, args);
    try writer.writeAll("\n");
    try writer.flush();
}

pub fn printSuccess(alloc: std.mem.Allocator, writer: *std.Io.Writer, comptime fmt: []const u8, args: anytype) !void {
    try printColored(alloc, writer, Color.green, fmt, args);
    try writer.writeAll("\n");
    try writer.flush();
}

pub fn printInfo(alloc: std.mem.Allocator, writer: *std.Io.Writer, comptime fmt: []const u8, args: anytype) !void {
    try printColored(alloc, writer, Color.cyan, fmt, args);
    try writer.writeAll("\n");
    try writer.flush();
}

pub fn replStyleDef(styleName: []const u8) [:0]const u8 {
    if (std.mem.eql(u8, styleName, "keyword")) return "color=magenta bold";
    if (std.mem.eql(u8, styleName, "number")) return "color=green";
    if (std.mem.eql(u8, styleName, "string")) return "color=yellow";
    if (std.mem.eql(u8, styleName, "operator")) return "color=blue";
    if (std.mem.eql(u8, styleName, "function")) return "color=cyan";
    if (std.mem.eql(u8, styleName, "atom")) return "color=yellow";
    return "color=default";
}

pub const base16 = [16][]const u8{
    "#101010", "#202020", "#2b2b2b", "#505050",
    "#b0b0b0", "#d0d0d0", "#e0e0e0", "#fafafa",
    "#ab4642", "#dc9656", "#f7ca88", "#a1b56c",
    "#86c1b9", "#7cafc2", "#ba8baf", "#a16946",
};

pub fn replStyleDefBase16(styleName: []const u8) [:0]const u8 {
    if (std.mem.eql(u8, styleName, "keyword")) return "color=" ++ base16[14] ++ " bold";
    if (std.mem.eql(u8, styleName, "number")) return "color=" ++ base16[11];
    if (std.mem.eql(u8, styleName, "string")) return "color=" ++ base16[10];
    if (std.mem.eql(u8, styleName, "operator")) return "color=" ++ base16[3];
    if (std.mem.eql(u8, styleName, "function")) return "color=" ++ base16[13];
    if (std.mem.eql(u8, styleName, "hash")) return "color=" ++ base16[10];
    return "color=" ++ base16[5];
}
