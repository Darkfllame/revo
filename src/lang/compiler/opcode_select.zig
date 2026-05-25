const std = @import("std");

const opcode = @import("revo").opcode;
const Opcode = opcode.Opcode;
const types_mod = @import("types.zig");

const TypeTag = enum { int, float, any };

fn toTagInfo(t: types_mod.TypeInfo) TypeTag {
    return switch (t) {
        .int => .int,
        .float => .float,
        else => .any,
    };
}

// single source of truth; declarative specs for all specializations
const Spec = struct { op: Opcode, t: TypeTag, spec: Opcode };
const specs = &[_]Spec{
    // arithmetic,,, int/float get specialized, others fall back
    .{ .op = .add, .t = .int, .spec = .add_int },
    .{ .op = .add, .t = .float, .spec = .add_int },
    .{ .op = .sub, .t = .int, .spec = .sub_int },
    .{ .op = .sub, .t = .float, .spec = .sub_int },
    .{ .op = .mul, .t = .int, .spec = .mul_int },
    .{ .op = .mul, .t = .float, .spec = .mul_int },
    .{ .op = .div, .t = .int, .spec = .div_int },
    .{ .op = .div, .t = .float, .spec = .div_float },
    .{ .op = .mod, .t = .int, .spec = .mod_int },
    // comparison
    .{ .op = .eq, .t = .int, .spec = .eq_int },
    .{ .op = .eq, .t = .float, .spec = .eq_int },
    .{ .op = .neq, .t = .int, .spec = .neq_int },
    .{ .op = .neq, .t = .float, .spec = .neq_int },
    .{ .op = .lt, .t = .int, .spec = .lt_int },
    .{ .op = .lt, .t = .float, .spec = .lt_int },
    .{ .op = .gt, .t = .int, .spec = .gt_int },
    .{ .op = .gt, .t = .float, .spec = .gt_int },
    .{ .op = .lte, .t = .int, .spec = .lte_int },
    .{ .op = .lte, .t = .float, .spec = .lte_int },
    .{ .op = .gte, .t = .int, .spec = .gte_int },
    .{ .op = .gte, .t = .float, .spec = .gte_int },
    // unary
    .{ .op = .negate, .t = .int, .spec = .negate_int },
    .{ .op = .negate, .t = .float, .spec = .negate_float },
};

fn select(op: Opcode, t: TypeTag) Opcode {
    inline for (specs) |s| if (s.op == op and s.t == t) return s.spec;
    return op;
}

pub fn selectBinaryOpcode(op: Opcode, left: types_mod.TypeInfo, right: types_mod.TypeInfo) Opcode {
    const g = switch (op) {
        .add_int => .add,
        .sub_int => .sub,
        .mul_int => .mul,
        .div_int, .div_float => .div,
        .mod_int => .mod,
        else => op,
    };
    const lt = toTagInfo(left);
    const rt = toTagInfo(right);
    if (lt != rt or lt == .any) return g;
    return select(g, lt);
}

pub fn selectComparisonOpcode(op: Opcode, left: types_mod.TypeInfo, right: types_mod.TypeInfo) Opcode {
    const g = switch (op) {
        .eq_int => .eq,
        .neq_int => .neq,
        .lt_int => .lt,
        .gt_int => .gt,
        .lte_int => .lte,
        .gte_int => .gte,
        else => op,
    };
    const lt = toTagInfo(left);
    const rt = toTagInfo(right);
    if (lt != rt or lt == .any) return g;
    return select(g, lt);
}

pub fn selectUnaryOpcode(op: Opcode, operand: types_mod.TypeInfo) Opcode {
    const g = switch (op) {
        .negate_int, .negate_float => .negate,
        else => op,
    };
    const t = toTagInfo(operand);
    if (t == .any) return g;
    return select(g, t);
}

test "selects properly" {
    try std.testing.expectEqual(.add_int, selectBinaryOpcode(.add, .int, .int));
    try std.testing.expectEqual(.mul_int, selectBinaryOpcode(.mul, .int, .int));
    try std.testing.expectEqual(.add_int, selectBinaryOpcode(.add, .float, .float));
    try std.testing.expectEqual(.div_float, selectBinaryOpcode(.div, .float, .float));
    try std.testing.expectEqual(.mod_int, selectBinaryOpcode(.mod, .int, .int));
    try std.testing.expectEqual(.add, selectBinaryOpcode(.add, .int, .float));
    try std.testing.expectEqual(.add, selectBinaryOpcode(.add, .any, .int));
    try std.testing.expectEqual(.eq_int, selectComparisonOpcode(.eq, .int, .int));
    try std.testing.expectEqual(.lt_int, selectComparisonOpcode(.lt, .int, .int));
    try std.testing.expectEqual(.eq_int, selectComparisonOpcode(.eq, .float, .float));
    try std.testing.expectEqual(.gte_int, selectComparisonOpcode(.gte, .float, .float));
    try std.testing.expectEqual(.negate_int, selectUnaryOpcode(.negate, .int));
    try std.testing.expectEqual(.negate_float, selectUnaryOpcode(.negate, .float));
    try std.testing.expectEqual(.negate, selectUnaryOpcode(.negate, .any));
}
