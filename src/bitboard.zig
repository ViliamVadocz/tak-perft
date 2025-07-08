const std = @import("std");
const state = @import("state.zig");

pub fn BitBoard(n: comptime_int) type {
    state.assertSize(n);
    return std.meta.Int(.unsigned, n * n);
}

pub fn BitBoardIndex(n: comptime_int) type {
    state.assertSize(n);
    return std.math.Log2Int(BitBoard(n));
}

pub fn rowBoard(n: comptime_int) BitBoard(n) {
    state.assertSize(n);
    return std.math.maxInt(BitBoard(n)) >> (@bitSizeOf(BitBoard(n)) - n);
}

pub fn rowBoardAt(n: comptime_int, row: BitBoardIndex(n)) BitBoard(n) {
    state.assertSize(n);
    std.debug.assert(row < n);
    return rowBoard(n) << row * n;
}

pub fn colBoard(n: comptime_int) BitBoard(n) {
    state.assertSize(n);
    var acc: BitBoard(n) = 1;
    for (1..n) |_| {
        acc |= (acc << n);
    }
    return acc;
}

pub fn colBoardAt(n: comptime_int, col: BitBoardIndex(n)) BitBoard(n) {
    state.assertSize(n);
    std.debug.assert(col < n);
    return colBoard(n) << col;
}

pub const Direction = enum { Left, Up, Right, Down };

pub fn ray(n: comptime_int, direction: Direction, index: BitBoardIndex(n)) BitBoard(n) {
    state.assertSize(n);
    const BB = BitBoard(n);
    const row = index / n; // TODO: Check if this is fine or not since n is comptime
    const col = index % n;
    const left_up_mask = if (index >= @bitSizeOf(BB) - 1) 0 else (@as(BB, std.math.maxInt(BB)) >> (index + 1)) << (index + 1);
    const right_down_mask = ((@as(BB, 1) << index) - 1);
    return switch (direction) {
        .Left => rowBoardAt(n, row) & left_up_mask,
        .Up => colBoardAt(n, col) & left_up_mask,
        .Right => rowBoardAt(n, row) & right_down_mask,
        .Down => colBoardAt(n, col) & right_down_mask,
    };
}

pub fn distanceToClosest(n: comptime_int, direction: Direction, hits: BitBoard(n), index: BitBoardIndex(n)) BitBoardIndex(n) {
    state.assertSize(n);
    std.debug.assert(hits > 0);
    const hit_index: BitBoardIndex(n) = @truncate(switch (direction) {
        .Left, .Up => @ctz(hits),
        .Right, .Down => @bitSizeOf(BitBoard(n)) - @clz(hits) - 1,
    });
    return switch (direction) {
        .Left => hit_index - index,
        .Up => (hit_index - index) / n,
        .Right => index - hit_index,
        .Down => (index - hit_index) / n,
    } -| 1;
}

pub fn spread(n: comptime_int, bb: BitBoard(n)) BitBoard(n) {
    const left = (bb << 1) & ~colBoardAt(n, 0);
    const up = (bb & ~rowBoardAt(n, n - 1)) << n;
    const right = (bb >> 1) & ~colBoardAt(n, n - 1);
    const down = bb >> n;
    return bb | left | up | right | down;
}

pub fn moveIndex(n: comptime_int, index: BitBoardIndex(n), direction: Direction) BitBoardIndex(n) {
    return switch (direction) {
        .Left => blk: {
            std.debug.assert(index < std.math.maxInt(BitBoardIndex(n))); // overflow
            std.debug.assert(index / n == (index + 1) / n); // wraparound
            break :blk index + 1;
        },
        .Up => blk: {
            std.debug.assert(index <= std.math.maxInt(BitBoardIndex(n)) - n); // overflow
            break :blk index + n;
        },
        .Right => blk: {
            std.debug.assert(index >= 1); // underflow
            std.debug.assert(index / n == (index - 1) / n); // wraparound
            break :blk index - 1;
        },
        .Down => blk: {
            std.debug.assert(index >= n); // underflow
            break :blk index - n;
        },
    };
}

pub fn extractAmountAt(bits: u8, amount: u4, at: u3) u8 {
    std.debug.assert(amount > 0);
    std.debug.assert(at + amount <= @bitSizeOf(u8));
    const mask: u8 = @truncate((@as(u9, 1) << amount) - 1);
    return (bits >> at) & mask;
}

test "extractAmountAt" {
    try std.testing.expectEqual(0b1010, extractAmountAt(0b0110_1001, 4, 2));
    try std.testing.expectEqual(0b011, extractAmountAt(0b1011_0111, 3, 1));
    try std.testing.expectEqual(0b00101, extractAmountAt(0b0010_1100, 5, 3));
    try std.testing.expectEqual(0b1010_1111, extractAmountAt(0b1010_1111, 8, 0));
}
