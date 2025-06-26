const std = @import("std");
const Stack = @import("stack.zig").Stack;
const Color = @import("color.zig").Color;

pub const min_n = 3;
pub const max_n = 8;

pub fn BitBoard(comptime n: u8) type {
    return switch (n) {
        3 => u9,
        4 => u16,
        5 => u25,
        6 => u36,
        7 => u49,
        8 => u64,
        else => unreachable,
    };
}

pub fn Game(comptime n: u8) type {
    std.debug.assert(n >= min_n);
    std.debug.assert(n <= max_n);

    return struct {
        stacks: [n * n]Stack(n) = @splat(Stack(n).init()),
        noble: BitBoard(n) = 0,
        caps: BitBoard(n) = 0,
        player: Color = .White,
        opening: bool = true,

        fn init() Game(n) {
            return .{};
        }
    };
}
