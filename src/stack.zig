const std = @import("std");

const state = @import("state.zig");
const Color = @import("color.zig").Color;

pub fn StackType(n: comptime_int) type {
    state.assertSize(n);
    return switch (n) {
        3 => u32, // 2 * (10 - 1) = 18
        4 => u32, // 2 * (15 - 1) = 28
        5 => u64, // 2 * 21 = 42
        6 => u64, // 2 * 30 = 60
        7 => u128, // 2 * 40 + 1 = 81
        8 => u128, // 2 * 50 + 1 = 101
        else => unreachable,
    };
}

pub fn Stack(n: comptime_int) type {
    state.assertSize(n);
    return struct {
        const MaxSize = @bitSizeOf(StackType(n)) - 1;
        _colors: StackType(n) = 1,

        pub fn init() Stack(n) {
            return .{};
        }

        pub fn size(self: Stack(n)) usize {
            return MaxSize - @clz(self._colors);
        }

        pub fn add_one(self: *Stack(n), color: Color) void {
            std.debug.assert(self.size() + 1 <= MaxSize);
            self.*._colors = (self._colors << 1) | @intFromEnum(color);
        }

        pub fn add(self: *Stack(n), amount: u4, colors: u8) void {
            std.debug.assert(self.size() + amount <= MaxSize);
            std.debug.assert(amount <= @bitSizeOf(u8));
            self.*._colors = (self._colors << amount) | colors;
        }

        pub fn take(self: *Stack(n), amount: u4) u8 {
            std.debug.assert(amount <= self.size());
            std.debug.assert(amount <= @bitSizeOf(u8));
            const shift: std.math.Log2Int(StackType(n)) = @truncate(MaxSize - @as(StackType(n), amount) + 1);
            const colors = (self._colors << shift) >> shift; // overflow?
            self.*._colors = self._colors >> amount;
            return @truncate(colors);
        }

        pub fn top(self: Stack(n)) Color {
            std.debug.assert(self.size() > 0);
            return @enumFromInt(self._colors & 1);
        }
    };
}

// TODO: Proper tests

test "add_one is same as add" {
    var stack_1 = Stack(6).init();
    var stack_2 = Stack(6).init();
    const colors_1 = [_]u1{ 0, 0, 1, 0, 1, 0, 1, 1 };
    const colors_2 = 0b0010_1011;
    for (colors_1) |color| {
        stack_1.add_one(@enumFromInt(color));
    }
    stack_2.add(8, colors_2);
    try std.testing.expectEqual(stack_1, stack_2);
}

test "take and add leaves the stack save" {
    var stack = Stack(5).init();
    stack.add(8, 0b1100_1010);
    const after_add = stack;
    const colors = stack.take(5);
    stack.add(5, colors);
    try std.testing.expectEqual(after_add, stack);
}

test "Stack.take" {
    var stack = Stack(7).init();
    stack.add(8, 0b0001_1101);
    stack.add(8, 0b0101_1100);
    const taken = stack.take(6);
    try std.testing.expectEqual(0b01_1100, taken);
}
