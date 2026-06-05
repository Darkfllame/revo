const std = @import("std");
const revo = @import("revo");
const types_mod = @import("types.zig");

pub const FieldDef = struct {
    name: []const u8,
    field_type: types_mod.TypeInfo,
    type_name: ?[]const u8 = null,
    default_val: ?revo.memory.Data = null,
};

fn typeNameToTypeInfo(name: []const u8) types_mod.TypeInfo {
    if (std.mem.eql(u8, name, "int")) return .int;
    if (std.mem.eql(u8, name, "float")) return .float;
    if (std.mem.eql(u8, name, "string")) return .string;
    if (std.mem.eql(u8, name, "bool")) return .bool;
    if (std.mem.eql(u8, name, "void")) return .void;
    return .any;
}

pub const StructLayouter = struct {
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator) StructLayouter {
        return .{ .alloc = alloc };
    }

    pub fn deinit(self: *StructLayouter) void {
        _ = self;
    }

    pub fn registerType(self: *StructLayouter, vm: *revo.VM, name: []const u8, defs: []const FieldDef) !revo.StructTypeID {
        var fields = try std.ArrayList(revo.vm.struct_mod.StructField).initCapacity(self.alloc, defs.len);
        defer fields.deinit(self.alloc);
        for (defs) |d| {
            const type_atom = if (d.type_name) |tn| blk: {
                break :blk try vm.internAtom(tn);
            } else if (d.field_type != .any) blk: {
                break :blk try vm.internAtom(types_mod.typeName(d.field_type));
            } else null;
            try fields.append(self.alloc, .{
                .name_atom = try vm.internAtom(d.name),
                .type_atom = type_atom,
                .default_val = d.default_val,
            });
        }
        return try vm.struct_types.registerType(name, fields.items, std.StringHashMap(revo.memory.Data).init(vm.runtime.alloc));
    }
};
