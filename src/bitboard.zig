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

/// Get a bitboard where the bottom row is set.
pub fn rowBoard(n: comptime_int) BitBoard(n) {
    state.assertSize(n);
    return std.math.maxInt(BitBoard(n)) >> (@bitSizeOf(BitBoard(n)) - n);
}

test rowBoard {
    try std.testing.expectEqual(0b111, rowBoard(3));
    try std.testing.expectEqual(0b1111, rowBoard(4));
    try std.testing.expectEqual(0b1_1111, rowBoard(5));
    try std.testing.expectEqual(0b11_1111, rowBoard(6));
    try std.testing.expectEqual(0b111_1111, rowBoard(7));
    try std.testing.expectEqual(0b1111_1111, rowBoard(8));
}

/// Get a bitboard where an arbitrary row is set.
pub fn rowBoardAt(n: comptime_int, row: BitBoardIndex(n)) BitBoard(n) {
    state.assertSize(n);
    std.debug.assert(row < n);
    return (comptime rowBoard(n)) << row * n;
}

test rowBoardAt {
    try std.testing.expectEqual(0b111_000_000, rowBoardAt(3, 2));
    try std.testing.expectEqual(rowBoard(5), rowBoardAt(5, 0));
    try std.testing.expectEqual(0b111111_000000_000000, rowBoardAt(6, 2));
    try std.testing.expectEqual(0xff_00_00_00_00_00, rowBoardAt(8, 5));
}

/// Get a bitboard where the rightmost column is set.
pub fn colBoard(n: comptime_int) BitBoard(n) {
    state.assertSize(n);
    var acc: BitBoard(n) = 1;
    for (1..n) |_| {
        acc |= (acc << n);
    }
    return acc;
}

test colBoard {
    try std.testing.expectEqual(0b001_001_001, colBoard(3));
    try std.testing.expectEqual(0b0001_0001_0001_0001, colBoard(4));
    try std.testing.expectEqual(0b00001_00001_00001_00001_00001, colBoard(5));
    try std.testing.expectEqual(0o01_01_01_01_01_01, colBoard(6));
    try std.testing.expectEqual(0b0000001_0000001_0000001_0000001_0000001_0000001_0000001, colBoard(7));
    try std.testing.expectEqual(0x01_01_01_01_01_01_01_01, colBoard(8));
}

/// Get a bitboard where an arbitrary column is set.
pub fn colBoardAt(n: comptime_int, col: BitBoardIndex(n)) BitBoard(n) {
    state.assertSize(n);
    std.debug.assert(col < n);
    return (comptime colBoard(n)) << col;
}

test colBoardAt {
    try std.testing.expectEqual(0b100_100_100, colBoardAt(3, 2));
    try std.testing.expectEqual(colBoard(4), colBoardAt(4, 0));
    try std.testing.expectEqual(0o04_04_04_04_04_04, colBoardAt(6, 2));
    try std.testing.expectEqual(0x20_20_20_20_20_20_20_20, colBoardAt(8, 5));
}

pub const Direction = enum { Left, Up, Right, Down };

/// Cast a ray in the direction specificied, starting at (but not including) the index.
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

test ray {
    try std.testing.expectEqual(0b00000_00000_00000_11100_00000, ray(5, .Left, 6));
    try std.testing.expectEqual(0b00010_00010_00010_00000_00000, ray(5, .Up, 6));
    try std.testing.expectEqual(0b000000_000000_010000_010000_010000_010000, ray(6, .Down, 28));
    try std.testing.expectEqual(0b000000_001111_000000_000000_000000_000000, ray(6, .Right, 28));
}

/// Get the distance to the closest hit.
/// The distance counts the number of squares strictly between the starting index and the closest hit bit.
pub fn distanceToClosest(n: comptime_int, direction: Direction, hits: BitBoard(n), index: BitBoardIndex(n)) BitBoardIndex(n) {
    state.assertSize(n);
    std.debug.assert(hits > 0);
    const hit_index: BitBoardIndex(n) = @truncate(switch (direction) {
        .Left, .Up => @ctz(hits),
        .Right, .Down => @bitSizeOf(BitBoard(n)) - @clz(hits) - 1,
    });
    // TODO: Assert that hit_index is in the correct direction from index
    return switch (direction) {
        .Left => hit_index - index,
        .Up => (hit_index - index) / n,
        .Right => index - hit_index,
        .Down => (index - hit_index) / n,
    } -| 1;
}

test distanceToClosest {
    try std.testing.expectEqual(1, distanceToClosest(4, .Left, 0b1100_0000_0000_0000, 12));
    try std.testing.expectEqual(2, distanceToClosest(4, .Up, 0b0001_0000_0000_0000, 0));
    try std.testing.expectEqual(1, distanceToClosest(5, .Right, 0b00000_00000_00000_00101_00000, 9));
    try std.testing.expectEqual(6, distanceToClosest(8, .Down, 0x00_00_00_00_00_00_00_10, 60));
}

/// Spread the set bits in all orthogonal directions.
/// This is used for floodfill.
pub fn spread(n: comptime_int, bb: BitBoard(n)) BitBoard(n) {
    const left = (bb << 1) & ~colBoardAt(n, 0);
    const up = (bb & ~rowBoardAt(n, n - 1)) << n;
    const right = (bb >> 1) & ~colBoardAt(n, n - 1);
    const down = bb >> n;
    return bb | left | up | right | down;
}

test spread {
    try std.testing.expectEqual(0b1111_1001_1001_1111, spread(4, 0b1001_0000_0000_1001));
    try std.testing.expectEqual(0b01000_11100_01010_00111_00010, spread(5, 0b00000_01000_00000_00010_00000));
    try std.testing.expectEqual(0b100011_110001_100000_100000_110001_100011, spread(6, 0b000001_100000_000000_000000_100000_000001));
}

/// Move an index in the specified direction with respect to the bitboard size.
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

/// Get a sequence bits at some index within a longer bitstring.
/// This is used to get the colors from the picked up stones.
pub fn extractAmountAt(bits: u8, amount: u4, at: u3) u8 {
    std.debug.assert(amount > 0);
    std.debug.assert(at + amount <= @bitSizeOf(u8));
    const mask: u8 = @truncate((@as(u9, 1) << amount) - 1);
    return (bits >> at) & mask;
}

test extractAmountAt {
    try std.testing.expectEqual(0b1010, extractAmountAt(0b0110_1001, 4, 2));
    try std.testing.expectEqual(0b011, extractAmountAt(0b1011_0111, 3, 1));
    try std.testing.expectEqual(0b00101, extractAmountAt(0b0010_1100, 5, 3));
    try std.testing.expectEqual(0b1010_1111, extractAmountAt(0b1010_1111, 8, 0));
}
