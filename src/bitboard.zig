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
