const std = @import("std");

const bitboard = @import("bitboard.zig");
const BitBoardIndex = bitboard.BitBoardIndex;
const lut = @import("lut.zig");
const State = @import("state.zig").State;
const tps = @import("tps.zig");
const Reserves = @import("reserves.zig").Reserves;

pub fn countPositions(n: comptime_int, state: *State(n), depth: u8) u64 {
    if (depth == 0) return 1;
    if (depth == 1) return countMoves(n, state);

    // TODO the rest
    return 0;
}

fn countMoves(n: comptime_int, state: *const State(n)) u64 {
    const empty: u64 = n * n - @popCount(state.white | state.black);
    if (state.opening()) return empty;
    const reserves = state.currentReserves();
    const placements = if (reserves.flats > 0) (if (reserves.caps > 0) 3 * empty else 2 * empty) else empty;

    const mine = state.currentPieces();
    const caps = state.noble & state.road;
    const walls = state.noble & ~state.road;

    // non-smash spreads
    const spreads = blk: {
        var spreads: u64 = 0;
        var index: BitBoardIndex(n) = 0;
        var pieces = mine;
        while (pieces > 0) {
            // std.debug.print("===\n", .{});
            const shift: BitBoardIndex(n) = @truncate(@ctz(pieces));
            // std.debug.print("pieces: {b}\nshift: {d}\n", .{ pieces, shift });
            pieces = (pieces >> shift) ^ 1;
            index += shift;
            // std.debug.print("index: {d}\n", .{index});
            const stack = state.stacks[index];
            // std.debug.print("stack: {b}\n", .{stack._colors});
            std.debug.assert(stack.top() == state.player);
            const size = stack.size();
            std.debug.assert(size > 0);
            const hand = @min(n, size); // carry limit
            for ([_]bitboard.Direction{ .Left, .Up, .Right, .Down }) |direction| {
                // std.debug.print("dir: {}\n", .{direction});
                const ray = bitboard.ray(n, direction, index);
                const hits = state.noble & ray;
                const distance = if (hits == 0) @popCount(ray) else bitboard.distanceToClosest(n, direction, hits, index);
                // std.debug.print("ray: {b}\nhits: {b}\ndist: {d}\n", .{ ray, hits, distance });
                if (distance == 0) continue;
                spreads += lut.spreads[hand - 1][distance - 1];
                // std.debug.print("spreads: {d}\n", .{spreads});
            }
        }
        break :blk spreads;
    };

    // smashes
    const smashes = blk: {
        var smashes: u64 = 0;
        var index: BitBoardIndex(n) = 0;
        var my_caps = mine & caps;
        while (my_caps > 0) {
            const shift: BitBoardIndex(n) = @truncate(@ctz(my_caps));
            my_caps = (my_caps >> shift) ^ 1;
            index += shift;
            const stack = state.stacks[index];
            std.debug.assert(stack.top() == state.player);
            const size = stack.size();
            std.debug.assert(size > 0);
            const hand = @min(n, size); // carry limit
            for ([_]bitboard.Direction{ .Left, .Up, .Right, .Down }) |direction| {
                const ray = bitboard.ray(n, direction, index);
                const wall_hits = walls & ray;
                if (wall_hits == 0) continue;
                const distance = bitboard.distanceToClosest(n, direction, wall_hits, index);
                smashes += lut.smashes[hand - 1][distance];
            }
        }
        break :blk smashes;
    };

    // std.debug.print("\n{d} {d} {d}\n", .{ placements, spreads, smashes });
    return placements + spreads + smashes;
}

test "countMoves opening" {
    inline for (3..9) |n| {
        const number = '0' + n;
        const empty_row = [_]u8{ 'x', number };
        const one_less_row = [_]u8{ 'x', number - 1 };
        const start_pos = empty_row ++ (("/" ++ empty_row) ** (n - 1)) ++ " 1 1";
        const corner_opening = ("2," ++ one_less_row) ++ (("/" ++ empty_row) ** (n - 1)) ++ " 2 1";
        const opposite_corners = ("2," ++ one_less_row) ++ (("/" ++ empty_row) ** (n - 2)) ++ "/" ++ one_less_row ++ ",1 1 2";

        // std.debug.print("{s}\n", .{start_pos});
        const p1 = try tps.parse(n, start_pos);
        // std.debug.print("{s}\n", .{corner_opening});
        const p2 = try tps.parse(n, corner_opening);
        // std.debug.print("{s}\n", .{opposite_corners});
        const p3 = try tps.parse(n, opposite_corners);

        try std.testing.expectEqual(n * n, countMoves(n, &p1));
        try std.testing.expectEqual(n * n - 1, countMoves(n, &p2));
        const piece_types = if ((Reserves(n){}).caps > 0) 3 else 2;
        try std.testing.expectEqual(piece_types * (n * n - 2) + 2, countMoves(n, &p3));
    }
}

test "countMoves spreads blocked" {
    const p3 = .{ "2,2S,x/2S,121,2S/x,2S,1 1 12", 4 };
    const p4 = .{ "2,2S,x2/2S,211,2S,x/x,2S,11,2S/x2,2S,1 1 11", 12 };
    const p5 = .{ "2,x4/x2,2S,x2/x,2C,12121,2S,x/x2,2S,x2/x4,1 1 10", 56 };
    const p6 = .{ "2,x5/x2,2S,x3/x,2S,1122121,2S,x2/x2,22C,121,2S,x/x3,2S,x2/x5,1 1 18", 80 };
    const p7 = .{ "2,x6/x7/x3,2C,x3/x2,2S,211221211,2S,x2/x3,2C,x3/x7/x6,1 1 15", 128 };
    const p8 = .{ "2,x7/x8/x3,2S,x4/x2,2S,1121211121,12C,x3/x3,22C,212121,2S,x2/x4,2S,x3/x8/x7,1 1 25", 164 };
    try std.testing.expectEqual(p3.@"1", countMoves(3, &try tps.parse(3, p3.@"0")));
    try std.testing.expectEqual(p4.@"1", countMoves(4, &try tps.parse(4, p4.@"0")));
    try std.testing.expectEqual(p5.@"1", countMoves(5, &try tps.parse(5, p5.@"0")));
    try std.testing.expectEqual(p6.@"1", countMoves(6, &try tps.parse(6, p6.@"0")));
    try std.testing.expectEqual(p7.@"1", countMoves(7, &try tps.parse(7, p7.@"0")));
    try std.testing.expectEqual(p8.@"1", countMoves(8, &try tps.parse(8, p8.@"0")));
}

test "countMoves max spreads" {
    const p3 = .{ "12121,x2/x,12121,x/x2,12121 1 9", 2 * (3 * 2) + 4 * (6 + 3) };
    const p4 = .{ "12121,x3/x,12121,x2/x2,12121,x/x3,12121 1 1", 2 * (4 * 3) + 4 * (14 + 10 + 4) };
    const p5 = .{ "1212121,x4/x,1212121,x3/x2,1212121,x2/x3,1212121,x/x4,1212121 1 1", 3 * (5 * 4) + 4 * (30 + 25 + 15 + 5) };
    const p6 = .{
        "1212121,x5/x,1212121,x4/x2,1212121,x3/x3,1212121,x2/x4,1212121,x/x5,1212121 1 24",
        3 * (6 * 5) + 4 * (62 + 56 + 41 + 21 + 6),
    };
    const p7 = .{
        "121212121,x6/x,121212121,x5/x2,121212121,x4/x3,121212121,x3/x4,121212121,x2/x5,121212121,x/x6,121212121 1 35",
        3 * (7 * 6) + 4 * (126 + 119 + 98 + 63 + 28 + 7),
    };
    const p8 = .{
        "12121212121,x7/x,12121212121,x6/x2,12121212121,x5/x3,12121212121,x4/x4,12121212121,x3/x5,12121212121,x2/x6,12121212121,x/x7,12121212121 1 48",
        3 * (8 * 7) + 4 * (254 + 246 + 218 + 162 + 92 + 36 + 8),
    };
    try std.testing.expectEqual(p3.@"1", countMoves(3, &try tps.parse(3, p3.@"0")));
    try std.testing.expectEqual(p4.@"1", countMoves(4, &try tps.parse(4, p4.@"0")));
    try std.testing.expectEqual(p5.@"1", countMoves(5, &try tps.parse(5, p5.@"0")));
    try std.testing.expectEqual(p6.@"1", countMoves(6, &try tps.parse(6, p6.@"0")));
    try std.testing.expectEqual(p7.@"1", countMoves(7, &try tps.parse(7, p7.@"0")));
    try std.testing.expectEqual(p8.@"1", countMoves(8, &try tps.parse(8, p8.@"0")));
}

test "countMoves smashes" {
    const p5 = .{ "x5/x,2C,x3/2S,221121C,112,1122,12S/x,212,x3/x,1S,x3 1 20", 68 };
    const p6 = .{ "x,2C,x4/x6/2S,212211C,12,1212,x,12S/x6/x6/x,21S,x4 1 18", 155 };
    const p7 = .{ "x,2C,x5/x,2C,x5/x7/2S,221122111C,x3,2,2S/x7/x7/1C,21S,x5 1 14", 254 };
    const p8 = .{ "x,2C,x6/x8/2S,22122111211C,x,2,2,2,x,2S/x,2212,x6/x,22,x6/x,2,x6/x,1S,x6/x,1C,x6 1 25", 485 };
    try std.testing.expectEqual(p5.@"1", countMoves(5, &try tps.parse(5, p5.@"0")));
    try std.testing.expectEqual(p6.@"1", countMoves(6, &try tps.parse(6, p6.@"0")));
    try std.testing.expectEqual(p7.@"1", countMoves(7, &try tps.parse(7, p7.@"0")));
    try std.testing.expectEqual(p8.@"1", countMoves(8, &try tps.parse(8, p8.@"0")));
}

test "countMoves random positions" {
    const p6 = .{
        .{ "1121S,x2,122S,2S,x/x,1S,x,2,2S,211S/x,2,12,12111S,2211C,1/x2,1,21S,2C,x/x3,2212211,122S,211S/2,21222S,21211221,1S,x,1 2 31", 99 },
        .{ "x,1222,1,1,1,2122C/12S,12,x,12S,x,12S/2S,121,2S,x,211S,x/x2,121S,12S,x,1/2S,21,21,2112S,11,112/22S,2S,12,21S,221C,211 2 31", 139 },
        .{ "1,2,x,12S,x2/122111,1,1222S,x,1S,11222S/x,2S,x,21,x2/2C,x2,21S,12112,1/221S,12,11C,1S,21,211/x,11,1222212S,212,2,x 1 31", 108 },
        .{ "x,1,x2,21S,2/2,x,121,211,12,22/21C,12111,x2,12,x/12S,x,222S,2,21,x/211121,x,111S,11S,x,22C/1222S,x,1222S,1211,x2 2 29", 114 },
        .{ "12S,x,1S,2S,x,12S/x,22,212,x,1,211S/1S,12S,112,x2,1111S/21C,12S,2S,121,x2/x,212212S,1222,22,2S,2/1S,12C,2,21,x,1221 1 30", 117 },
    };
    inline for (p6) |p| try std.testing.expectEqual(p.@"1", countMoves(6, &try tps.parse(6, p.@"0")));
}
