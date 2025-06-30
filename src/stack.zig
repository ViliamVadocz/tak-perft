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

pub fn AmountType(n: comptime_int) type {
    state.assertSize(n);
    return switch (n) {
        3 => u5,
        4 => u5,
        5 => u6,
        6 => u6,
        7 => u7,
        8 => u7,
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

        pub fn add(self: *Stack(n), amount: AmountType(n), colors: StackType(n)) void {
            std.debug.assert(self.size() + amount <= MaxSize);
            self.*._colors = (self._colors << amount) | colors;
        }

        pub fn take(self: *Stack(n), amount: AmountType(n)) StackType(n) {
            std.debug.assert(amount <= self.size());
            const shift = MaxSize - amount + 1;
            const colors = (self._colors << shift) >> shift;
            self.*._colors = self._colors >> amount;
            return colors;
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
    stack.add(16, 0b0001_1101_0101_1100);
    const taken = stack.take(10);
    try std.testing.expectEqual(0b01_0101_1100, taken);
}
