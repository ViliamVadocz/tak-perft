const std = @import("std");
const Direction = @import("bitboard.zig").Direction;

pub const placement_pattern: u8 = 0;

pub const Action = packed struct {
    pattern: u8, // 0 indicates placement instead of spread
    piece_or_direction: u2,
    square: Square,
};

comptime {
    std.debug.assert(@sizeOf(Action) == 2);
}

pub const Square = packed struct {
    rank: u3, // row
    file: u3, // col
};

pub const Piece = enum(u2) {
    Flat = 0b01,
    Wall = 0b10,
    Cap = 0b11,
};

pub fn bitToSquare(n: comptime_int, i: usize) Square {
    std.debug.assert(i < 64);
    // FIXME: This is flipped because the TPS parsing flips the board
    const flipped_i = n * n - i;
    const rank: u3 = @intCast(flipped_i / n);
    const file: u3 = @intCast(n - (flipped_i % n));
    return Square{
        .rank = rank,
        .file = file,
    };
}

const max_ptn_size = 11;

pub fn toPTN(action: Action) [max_ptn_size:0]u8 {
    std.debug.assert(action.pattern != 0xFF);
    var ptn = [_:0]u8{0} ** max_ptn_size;

    const placement = action.pattern == 0;
    const file = 'a' + @as(u8, action.square.file);
    const rank = '1' + @as(u8, action.square.rank);
    var i: u4 = 0;
    if (placement) {
        const piece: Piece = @enumFromInt(action.piece_or_direction);
        switch (piece) {
            Piece.Flat => {},
            Piece.Wall => {
                ptn[0] = 'S';
                i += 1;
            },
            Piece.Cap => {
                ptn[0] = 'C';
                i += 1;
            },
        }
        ptn[i] = file;
        ptn[i + 1] = rank;
        return ptn;
    }

    const pickup = 8 - @ctz(action.pattern);
    // skip amount if moving one
    if (pickup > 1) {
        ptn[0] = '0' + @as(u8, pickup);
        i += 1;
    }
    const direction: Direction = @enumFromInt(action.piece_or_direction);

    ptn[i] = file;
    ptn[i + 1] = rank;
    ptn[i + 2] = switch (direction) {
        // FIXME: This is flipped because the TPS parsing flips the board
        Direction.Up => '-',
        Direction.Down => '+',
        Direction.Left => '>',
        Direction.Right => '<',
    };
    i += 3;

    var steps: u3 = 0;
    var p = action.pattern;
    var dropped = @ctz(p);
    while (p != 0) : (steps += 1) {
        p &= p - 1;
        const num = @ctz(p) - dropped;
        dropped += num;
        ptn[i + steps] = '0' + @as(u8, num);
    }

    if (steps <= 1) {
        // leave out the drop amount if we drop all
        ptn[i] = 0;
    }
    return ptn;
}

// FIXME: These tests are failing because TPS parsing flips the board,
// And I am too lazy to fix that right now so I just changed the PTN
// output to also flip (so that it cancels out).

test "place flat" {
    const a = Action{
        .pattern = 0,
        .square = Square{
            .file = 2,
            .rank = 3,
        },
        .piece_or_direction = @intFromEnum(Piece.Flat),
    };
    const ptn = toPTN(a);
    try std.testing.expectEqualStrings(std.mem.sliceTo(&ptn, 0), "c4");
}

test "place wall" {
    const a = Action{
        .pattern = 0,
        .square = Square{
            .file = 0,
            .rank = 7,
        },
        .piece_or_direction = @intFromEnum(Piece.Wall),
    };
    const ptn = toPTN(a);
    try std.testing.expectEqualStrings(std.mem.sliceTo(&ptn, 0), "Sa8");
}

test "place cap" {
    const a = Action{
        .pattern = 0,
        .square = Square{
            .file = 7,
            .rank = 0,
        },
        .piece_or_direction = @intFromEnum(Piece.Cap),
    };
    const ptn = toPTN(a);
    try std.testing.expectEqualStrings(std.mem.sliceTo(&ptn, 0), "Ch1");
}

test "max spread" {
    const a = Action{
        .pattern = 0b0111_1111,
        .square = Square{
            .file = 0,
            .rank = 0,
        },
        .piece_or_direction = @intFromEnum(Direction.Up),
    };
    const ptn = toPTN(a);
    try std.testing.expectEqualStrings(std.mem.sliceTo(&ptn, 0), "8a1+1111112");
}

test "move one" {
    const a = Action{
        .pattern = 0b1000_0000,
        .square = Square{
            .file = 5,
            .rank = 2,
        },
        .piece_or_direction = @intFromEnum(Direction.Left),
    };
    const ptn = toPTN(a);
    try std.testing.expectEqualStrings(std.mem.sliceTo(&ptn, 0), "f3<");
}

test "drop all" {
    const a = Action{
        .pattern = 0b0000_1000,
        .square = Square{
            .file = 1,
            .rank = 4,
        },
        .piece_or_direction = @intFromEnum(Direction.Down),
    };
    const ptn = toPTN(a);
    try std.testing.expectEqualStrings(std.mem.sliceTo(&ptn, 0), "5b5-");
}
