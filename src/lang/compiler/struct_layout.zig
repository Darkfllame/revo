const std = @import("std");

const types_mod = @import("types.zig");

pub const Field = struct { name: []const u8, field_type: types_mod.TypeInfo, offset: u32, size: u32 };

pub const StructDescriptor = struct {
    name: []const u8,
    fields: []Field,
    size: u32,
    alignment: u32,

    pub fn deinit(self: StructDescriptor, alloc: std.mem.Allocator) void {
        for (self.fields) |f| alloc.free(f.name);
        alloc.free(self.fields);
        alloc.free(self.name);
    }
    pub fn getFieldOffset(self: StructDescriptor, name: []const u8) ?u32 {
        for (self.fields) |f| if (std.mem.eql(u8, f.name, name)) return f.offset;
        return null;
    }
    pub fn getFieldType(self: StructDescriptor, name: []const u8) ?types_mod.TypeInfo {
        for (self.fields) |f| if (std.mem.eql(u8, f.name, name)) return f.field_type;
        return null;
    }
};

pub const StructLayouter = struct {
    alloc: std.mem.Allocator,
    layouts: std.StringHashMap(StructDescriptor),

    pub fn init(alloc: std.mem.Allocator) StructLayouter {
        return .{ .alloc = alloc, .layouts = std.StringHashMap(StructDescriptor).init(alloc) };
    }
    pub fn deinit(self: *StructLayouter) void {
        var it = self.layouts.valueIterator();
        while (it.next()) |d| d.deinit(self.alloc);
        self.layouts.deinit();
    }
    pub fn layoutStruct(self: *StructLayouter, name: []const u8, defs: []const FieldDef) !StructDescriptor {
        var fields = try std.ArrayList(Field).initCapacity(self.alloc, defs.len);
        defer fields.deinit(self.alloc);
        var off: u32 = 0;
        for (defs) |d| {
            const sz: u32 = switch (d.field_type) { // explicit type avoids comptime_int inference
                .bool => 1,
                .int => 8,
                .float => 8,
                .string => 16,
                .atom => 8,
                .void => 0,
                else => 16,
            };
            const alignment = @min(8, sz);
            const rem = off % alignment;
            if (rem != 0) off += alignment - rem;
            try fields.append(self.alloc, .{ .name = try self.alloc.dupe(u8, d.name), .field_type = d.field_type, .offset = off, .size = sz });
            off += sz;
        }
        const rem = off % 8;
        if (rem != 0) off += 8 - rem;
        const desc = StructDescriptor{
            .name = try self.alloc.dupe(u8, name),
            .fields = try fields.toOwnedSlice(self.alloc),
            .size = off,
            .alignment = 8,
        };
        try self.layouts.put(name, desc);
        return desc;
    }
    pub fn getLayout(self: StructLayouter, name: []const u8) ?StructDescriptor {
        return self.layouts.get(name);
    }
    pub fn hasLayout(self: StructLayouter, name: []const u8) bool {
        return self.layouts.contains(name);
    }
};

pub const FieldDef = struct { name: []const u8, field_type: types_mod.TypeInfo };

test "struct layout: single field" {
    var l = StructLayouter.init(std.testing.allocator);
    defer l.deinit();
    const d = try l.layoutStruct("Point", &.{.{ .name = "x", .field_type = .int }});
    try std.testing.expect(d.fields.len == 1);
    try std.testing.expect(d.fields[0].offset == 0);
}
test "struct layout: alignment padding" {
    var l = StructLayouter.init(std.testing.allocator);
    defer l.deinit();
    const d = try l.layoutStruct("Mixed", &.{ .{ .name = "a", .field_type = .bool }, .{ .name = "b", .field_type = .int } });
    try std.testing.expect(d.fields[1].offset == 8);
}
