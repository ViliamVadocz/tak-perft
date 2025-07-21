const std = @import("std");

const Color = @import("color.zig").Color;
const bitboard = @import("bitboard.zig");
const BitBoard = bitboard.BitBoard;
const BitBoardIndex = bitboard.BitBoardIndex;
const Direction = bitboard.Direction;
const lut = @import("lut.zig");
const State = @import("state.zig").State;
const tps = @import("tps.zig");
const Reserves = @import("reserves.zig").Reserves;
const Stack = @import("stack.zig").Stack;
const zobrist = @import("zobrist.zig");

pub fn countPositions(n: comptime_int, state: *State(n), depth: u8) u64 {
    state.checkInvariants();
    if (depth == 0) return 1;
    if (state.terminal()) return 0;
    if (depth == 1) return countMoves(n, state);
    if (state.opening()) return opening(n, state, depth - 1);
    return countPositionsRec(n, state, depth - 1);
}

pub fn opening(n: comptime_int, state: *State(n), depth: u8) u64 {
    std.debug.assert(state.opening());
    var positions: u64 = 0;
    const before = state.*; // TODO: remove this after debugging
    // swap color before getting pieces and reserves to observe swap rule
    state.player.advance();
    const color = state.player;
    const reserves = state.reserves_mut().@"0";
    const pieces = state.pieces_mut().@"0";
    const occupied = state.road; // opening only has flats
    std.debug.assert(@popCount(occupied) <= 1);
    reserves.*.flats -= 1;
    state.hash ^= zobrist.player_black;
    for (0..n * n) |i| {
        const bit = @as(BitBoard(n), 1) << @truncate(i);
        if (occupied & bit != 0) continue;
        const stack = &state.stacks[i];
        stack.add_one(color);
        std.debug.assert(stack.size() == 1);
        pieces.* |= bit;
        state.road |= bit;
        state.hash ^= zobrist.stack_color[@intFromEnum(color)][0][i];
        positions += countPositions(n, state, depth);
        _ = stack.take(1);
        std.debug.assert(stack.size() == 0);
        pieces.* ^= bit;
        std.debug.assert(pieces.* & bit == 0);
        state.road ^= bit;
        std.debug.assert(state.road & bit == 0);
        state.hash ^= zobrist.stack_color[@intFromEnum(color)][0][i];
    }
    reserves.*.flats += 1;
    state.player.advance();
    state.hash ^= zobrist.player_black;
    std.debug.assert(std.meta.eql(before, state.*));
    return positions;
}

fn countPositionsRec(n: comptime_int, state: *State(n), depth: u8) u64 {
    std.debug.assert(!state.opening());
    var positions: u64 = 0;
    state.player.advance();
    state.hash ^= zobrist.player_black;
    const before = state.*; // TODO: remove this after debugging
    positions += flatPlacements(n, state, depth);
    std.debug.assert(std.meta.eql(before, state.*));
    positions += capPlacements(n, state, depth);
    std.debug.assert(std.meta.eql(before, state.*));
    positions += nonSmashSpreads(n, state, depth);
    std.debug.assert(std.meta.eql(before, state.*));
    positions += smashSpreads(n, state, depth);
    std.debug.assert(std.meta.eql(before, state.*));
    state.player.advance(); // unswap color
    state.hash ^= zobrist.player_black;
    return positions;
}

fn flatPlacements(n: comptime_int, state: *State(n), depth: u8) u64 {
    var positions: u64 = 0;
    const reserves = state.reserves_mut().@"1";
    if (reserves.flats == 0) return 0;
    const pieces = state.pieces_mut().@"1";
    const color = state.player.next();
    const empty = ~(state.road | state.noble);
    reserves.flats -= 1;
    // iterate over set bits
    var iter = empty;
    while (iter != 0) : (iter &= iter - 1) {
        const i: BitBoardIndex(n) = @truncate(@ctz(iter));
        const bit = @as(BitBoard(n), 1) << i;
        const stack = &state.stacks[i];
        stack.add_one(color);
        std.debug.assert(stack.size() == 1);
        pieces.* |= bit;
        state.hash ^= zobrist.stack_color[@intFromEnum(color)][0][i];
        // flat
        state.road |= bit;
        positions += countPositions(n, state, depth);
        state.road ^= bit;
        std.debug.assert(state.road & bit == 0);
        // wall
        state.noble |= bit;
        state.hash ^= zobrist.wall[i];
        positions += countPositions(n, state, depth);
        state.noble ^= bit;
        std.debug.assert(state.noble & bit == 0);
        _ = stack.take(1);
        std.debug.assert(stack.size() == 0);
        pieces.* ^= bit;
        std.debug.assert(pieces.* & bit == 0);
        state.hash ^= zobrist.wall[i];
        state.hash ^= zobrist.stack_color[@intFromEnum(color)][0][i];
    }
    reserves.flats += 1;
    return positions;
}

fn capPlacements(n: comptime_int, state: *State(n), depth: u8) u64 {
    var positions: u64 = 0;
    const reserves = state.reserves_mut().@"1";
    if (reserves.caps == 0) return 0;
    const pieces = state.pieces_mut().@"1";
    const color = state.player.next();
    const empty = ~(state.road | state.noble);
    reserves.caps -= 1;
    // iterate over set bits
    var iter = empty;
    while (iter != 0) : (iter &= iter - 1) {
        const i: BitBoardIndex(n) = @truncate(@ctz(iter));
        const bit = @as(BitBoard(n), 1) << i;
        const stack = &state.stacks[i];
        stack.add_one(color);
        std.debug.assert(stack.size() == 1);
        pieces.* |= bit;
        const capstone_placement_hash = zobrist.stack_color[@intFromEnum(color)][0][i] ^ zobrist.capstone[i];
        state.hash ^= capstone_placement_hash;
        // cap
        state.road |= bit;
        state.noble |= bit;
        positions += countPositions(n, state, depth);
        state.road ^= bit;
        std.debug.assert(state.road & bit == 0);
        state.noble ^= bit;
        std.debug.assert(state.noble & bit == 0);
        _ = stack.take(1);
        std.debug.assert(stack.size() == 0);
        pieces.* ^= bit;
        std.debug.assert(pieces.* & bit == 0);
        state.hash ^= capstone_placement_hash;
    }
    reserves.caps += 1;
    return positions;
}

fn nonSmashSpreads(n: comptime_int, state: *State(n), depth: u8) u64 {
    var positions: u64 = 0;
    const opp_pieces, const my_pieces = state.pieces_mut();
    const color = state.player.next();
    // for unmake
    var dropped_amounts: [n - 2]u8 = undefined;
    var dropped_times: usize = 0;
    const white_before_spread = state.white;
    const black_before_spread = state.black;
    const noble_before_spread = state.noble;
    const road_before_spread = state.road;
    // iterate over set bits
    var iter = my_pieces.*;
    while (iter != 0) : (iter &= iter - 1) {
        const i: BitBoardIndex(n) = @truncate(@ctz(iter));
        const start_bit = @as(BitBoard(n), 1) << i;
        std.debug.assert(@popCount(my_pieces.* & start_bit) == 1);
        const start_stack = &state.stacks[i];
        std.debug.assert(start_stack.top() == color);
        const hand = @min(n, start_stack.size()); // carry limit
        std.debug.assert(hand > 0);
        std.debug.assert(hand <= 8);
        const noble = (state.noble & start_bit) != 0;
        const road = (state.road & start_bit) != 0;
        const hash_before = state.hash;
        for ([_]bitboard.Direction{ .Left, .Up, .Right, .Down }) |direction| {
            const ray = bitboard.ray(n, direction, i);
            const hits = state.noble & ray;
            const distance = if (hits == 0) @popCount(ray) else bitboard.distanceToClosest(n, direction, hits, i);
            if (distance == 0) continue;
            std.debug.assert(distance < n);
            for (1..(@as(u16, 1) << hand)) |pattern| {
                std.debug.assert(@popCount(pattern) > 0);
                std.debug.assert(@ctz(pattern) < hand);
                if (@popCount(pattern) > distance) continue;
                // std.debug.print("=== hand: {d}, pattern: {b}\n", .{ hand, pattern });
                // pick up stones
                var dropped = @ctz(pattern);
                const pickup_amount: u4 = @truncate(hand - dropped);
                const picked_up_stones = start_stack.take(pickup_amount);
                // std.debug.print("amount: {d}, stones: {b}\n", .{ pickup_amount, picked_up_stones });
                std.debug.assert(pickup_amount > 0);
                my_pieces.* ^= start_bit; // unset my pieces, will reset based on top of stack later
                std.debug.assert(my_pieces.* & start_bit == 0);
                state.noble &= ~start_bit; // you cannot leave a wall or capstone
                const stack_size_after_pickup = start_stack.size();
                if (stack_size_after_pickup > 0) {
                    state.road |= start_bit;
                    switch (start_stack.top()) {
                        .White => state.white |= start_bit,
                        .Black => state.black |= start_bit,
                    }
                } else {
                    state.road &= ~start_bit;
                }
                std.debug.assert(state.white & state.black == 0);
                std.debug.assert(state.white ^ state.black == state.noble | state.road);
                // update hash at pickup
                state.hash ^= zobrist.hash_update_after_stack_change(n, stack_size_after_pickup, picked_up_stones, pickup_amount, i);
                if (noble) {
                    if (road) {
                        state.hash ^= zobrist.capstone[i];
                    } else {
                        state.hash ^= zobrist.wall[i];
                    }
                }
                // drop stones based on pattern
                dropped_times = 0;
                var p = pattern & (pattern - 1);
                var moved_index = bitboard.moveIndex(n, i, direction);
                while (p != 0) : ({
                    p &= p - 1;
                    moved_index = bitboard.moveIndex(n, moved_index, direction);
                }) {
                    const bit = @as(BitBoard(n), 1) << moved_index;
                    std.debug.assert(state.noble & bit == 0);
                    const stack = &state.stacks[moved_index];
                    std.debug.assert(@ctz(p) < 8);
                    const dropping: u3 = @truncate(@ctz(p) - dropped);
                    std.debug.assert(dropping > 0);
                    dropped_amounts[dropped_times] = dropping;
                    dropped_times += 1;
                    dropped += dropping;
                    std.debug.assert(hand - dropped < 8);
                    const colors = bitboard.extractAmountAt(picked_up_stones, dropping, @truncate(hand - dropped));
                    // std.debug.print("dropping: {d}, colors: {b}\n", .{ dropping, colors });
                    state.hash ^= zobrist.hash_update_after_stack_change(n, stack.size(), colors, dropping, moved_index);
                    stack.add(dropping, colors);
                    state.road |= bit;
                    switch (stack.top()) {
                        .White => {
                            state.white |= bit;
                            state.black &= ~bit;
                        },
                        .Black => {
                            state.black |= bit;
                            state.white &= ~bit;
                        },
                    }
                    std.debug.assert(state.white & state.black == 0);
                    std.debug.assert(state.white ^ state.black == state.noble | state.road);
                }
                const final_drop: u4 = @truncate(hand - dropped);
                const rest = bitboard.extractAmountAt(picked_up_stones, final_drop, 0);
                // std.debug.print("final_drop: {d}, rest: {b}\n", .{ final_drop, rest });
                std.debug.assert(rest & 1 == @intFromEnum(color));
                std.debug.assert(dropped + final_drop == hand);
                const final_bit = @as(BitBoard(n), 1) << moved_index;
                std.debug.assert(state.noble & final_bit == 0);
                const final_stack = &state.stacks[moved_index];
                // update hash after drop
                state.hash ^= zobrist.hash_update_after_stack_change(n, final_stack.size(), rest, final_drop, moved_index);
                final_stack.add(final_drop, rest);
                my_pieces.* |= final_bit;
                opp_pieces.* &= ~final_bit;
                if (noble) {
                    state.noble |= final_bit;
                    if (road) {
                        state.hash ^= zobrist.capstone[moved_index];
                    } else {
                        state.hash ^= zobrist.wall[moved_index];
                    }
                } // final bit cannot already be noble
                if (road) {
                    state.road |= final_bit;
                } else {
                    state.road &= ~final_bit;
                }
                positions += countPositions(n, state, depth);

                // unmake
                state.white = white_before_spread;
                state.black = black_before_spread;
                state.noble = noble_before_spread;
                state.road = road_before_spread;
                start_stack.add(pickup_amount, picked_up_stones);
                _ = final_stack.take(final_drop);
                moved_index = bitboard.moveIndex(n, i, direction);
                for (0..dropped_times) |drop_i| {
                    const amount = dropped_amounts[drop_i];
                    std.debug.assert(amount < 8);
                    _ = state.stacks[moved_index].take(@truncate(amount));
                    moved_index = bitboard.moveIndex(n, moved_index, direction);
                }
                state.hash = hash_before;
            }
        }
    }
    return positions;
}

fn smashSpreads(n: comptime_int, state: *State(n), depth: u8) u64 {
    var positions: u64 = 0;
    const opp_pieces, const my_pieces = state.pieces_mut();
    const color = state.player.next();
    const walls = state.noble & ~state.road;
    // for unmake
    var dropped_amounts: [n - 2]u8 = undefined;
    var dropped_times: usize = 0;
    const white_before_spread = state.white;
    const black_before_spread = state.black;
    const road_before_spread = state.road;
    // iterate over my capstones
    var iter = my_pieces.* & state.noble & state.road;
    while (iter != 0) : (iter &= iter - 1) {
        const i: BitBoardIndex(n) = @truncate(@ctz(iter));
        const start_bit = @as(BitBoard(n), 1) << i;
        std.debug.assert(@popCount(my_pieces.* & start_bit) == 1);
        std.debug.assert(@popCount(state.noble & start_bit) == 1);
        std.debug.assert(@popCount(state.road & start_bit) == 1);
        const start_stack = &state.stacks[i];
        std.debug.assert(start_stack.top() == color);
        const hand = @min(n, start_stack.size()); // carry limit
        std.debug.assert(hand > 0);
        std.debug.assert(hand <= 8);
        // update hash at pickup
        const hash_before = state.hash;
        for ([_]bitboard.Direction{ .Left, .Up, .Right, .Down }) |direction| {
            const ray = bitboard.ray(n, direction, i);
            const wall_hits = walls & ray;
            if (wall_hits == 0) continue;
            const distance = bitboard.distanceToClosest(n, direction, wall_hits, i);
            const all_hits = state.noble & ray;
            if (all_hits != 0) { // check for capstone blocking
                const cap_distance = bitboard.distanceToClosest(n, direction, all_hits, i);
                if (cap_distance < distance) continue;
            }
            std.debug.assert(distance < n - 1);
            for ((@as(u16, 1) << (hand - 1))..(@as(u16, 1) << hand)) |pattern| {
                std.debug.assert(@popCount(pattern & (@as(BitBoard(n), 1) << (hand - 1))) == 1);
                if (@popCount(pattern) != distance + 1) continue;
                std.debug.assert(@ctz(pattern) < hand);
                var dropped = @ctz(pattern);
                const pickup_amount: u4 = @truncate(hand - dropped);
                std.debug.assert(pickup_amount > 0);
                std.debug.assert(pickup_amount <= 8);
                const picked_up_stones = start_stack.take(pickup_amount);
                state.noble ^= start_bit;
                std.debug.assert(state.noble & start_bit == 0);
                my_pieces.* ^= start_bit;
                std.debug.assert(my_pieces.* & start_bit == 0);
                const stack_size_after_pickup = start_stack.size();
                if (stack_size_after_pickup > 0) {
                    std.debug.assert(@popCount(state.road & start_bit) == 1);
                    switch (start_stack.top()) {
                        .White => state.white |= start_bit,
                        .Black => state.black |= start_bit,
                    }
                } else {
                    state.road ^= start_bit;
                }
                std.debug.assert(state.white & state.black == 0);
                std.debug.assert(state.white ^ state.black == state.noble | state.road);
                // update hash after pickup
                state.hash ^= zobrist.hash_update_after_stack_change(n, stack_size_after_pickup, picked_up_stones, pickup_amount, i);
                state.hash ^= zobrist.capstone[i]; // always capstone leaving
                // drop stones based on pattern
                dropped_times = 0;
                var p = pattern & (pattern - 1);
                var moved_index = bitboard.moveIndex(n, i, direction);
                while (p != 0) : ({
                    p &= p - 1;
                    moved_index = bitboard.moveIndex(n, moved_index, direction);
                }) {
                    const bit = @as(BitBoard(n), 1) << moved_index;
                    std.debug.assert(state.noble & bit == 0);
                    const stack = &state.stacks[moved_index];
                    std.debug.assert(@ctz(p) < 8);
                    const dropping: u3 = @truncate(@ctz(p) - dropped);
                    std.debug.assert(dropping > 0);
                    dropped_amounts[dropped_times] = dropping;
                    dropped_times += 1;
                    dropped += dropping;
                    std.debug.assert(hand - dropped < 8);
                    const colors = bitboard.extractAmountAt(picked_up_stones, dropping, @truncate(hand - dropped));
                    state.hash ^= zobrist.hash_update_after_stack_change(n, stack.size(), colors, dropping, moved_index);
                    stack.add(dropping, colors);
                    state.road |= bit;
                    switch (stack.top()) {
                        .White => {
                            state.white |= bit;
                            state.black &= ~bit;
                        },
                        .Black => {
                            state.black |= bit;
                            state.white &= ~bit;
                        },
                    }
                    std.debug.assert(state.white & state.black == 0);
                    std.debug.assert(state.white ^ state.black == state.noble | state.road);
                }
                const final_drop: u4 = @truncate(hand - dropped);
                std.debug.assert(final_drop == 1);
                const rest = bitboard.extractAmountAt(picked_up_stones, final_drop, 0);
                std.debug.assert(rest == @intFromEnum(color));
                const final_bit = @as(BitBoard(n), 1) << moved_index;
                std.debug.assert(@popCount(state.noble & final_bit) == 1);
                std.debug.assert(@popCount(~state.road & final_bit) == 1);
                const final_stack = &state.stacks[moved_index];
                state.hash ^= zobrist.stack_color[@intFromEnum(color)][final_stack.size()][moved_index];
                state.hash ^= zobrist.wall[moved_index] ^ zobrist.capstone[moved_index]; // was wall, now is capstone
                final_stack.add(final_drop, rest);
                my_pieces.* |= final_bit;
                opp_pieces.* &= ~final_bit;
                std.debug.assert(@popCount(state.noble & final_bit) == 1);
                state.road ^= final_bit;
                std.debug.assert(@popCount(state.road & final_bit) == 1);

                positions += countPositions(n, state, depth);

                // unmake
                state.white = white_before_spread;
                state.black = black_before_spread;
                state.road = road_before_spread;
                state.noble |= start_bit;
                start_stack.add(pickup_amount, picked_up_stones);
                _ = final_stack.take(final_drop);
                moved_index = bitboard.moveIndex(n, i, direction);
                for (0..dropped_times) |drop_i| {
                    const amount = dropped_amounts[drop_i];
                    std.debug.assert(amount < 8);
                    _ = state.stacks[moved_index].take(@truncate(amount));
                    moved_index = bitboard.moveIndex(n, moved_index, direction);
                }
                state.hash = hash_before;
            }
        }
    }
    return positions;
}

// TODO: Optimize (rewrite bit iteration loops to use `mask &= mask - 1`)
fn countMoves(n: comptime_int, state: *const State(n)) u64 {
    const empty: u64 = n * n - @popCount(state.white | state.black);
    if (state.opening()) return empty;
    const reserves = state.reserves().@"0";
    const placements = if (reserves.flats > 0) (if (reserves.caps > 0) 3 * empty else 2 * empty) else empty;

    const mine = state.pieces().@"0";
    const caps = state.noble & state.road;
    const walls = state.noble & ~state.road;

    // non-smash spreads
    const spreads = blk: {
        var spreads: u64 = 0;
        var index: BitBoardIndex(n) = 0;
        var pieces = mine;
        while (pieces > 0) {
            const shift: BitBoardIndex(n) = @truncate(@ctz(pieces));
            pieces = (pieces >> shift) ^ 1;
            index += shift;
            const stack = state.stacks[index];
            std.debug.assert(stack.top() == state.player);
            const size = stack.size();
            std.debug.assert(size > 0);
            const hand = @min(n, size); // carry limit
            std.debug.assert(hand > 0);
            std.debug.assert(hand <= 8);
            for ([_]bitboard.Direction{ .Left, .Up, .Right, .Down }) |direction| {
                const ray = bitboard.ray(n, direction, index);
                const hits = state.noble & ray;
                const distance = if (hits == 0) @popCount(ray) else bitboard.distanceToClosest(n, direction, hits, index);
                if (distance == 0) continue;
                spreads += lut.spreads[hand - 1][distance - 1];
            }
        }
        break :blk spreads;
    };

    // smashes
    const smashes = blk: {
        var smashes: u64 = 0;
        var index: BitBoardIndex(n) = 0;
        var my_caps = mine & caps;
        std.debug.assert(@popCount(my_caps) <= 2);
        while (my_caps > 0) {
            const shift: BitBoardIndex(n) = @truncate(@ctz(my_caps));
            my_caps = (my_caps >> shift) ^ 1;
            index += shift;
            const stack = state.stacks[index];
            std.debug.assert(stack.top() == state.player);
            const size = stack.size();
            std.debug.assert(size > 0);
            const hand = @min(n, size); // carry limit
            std.debug.assert(hand > 0);
            std.debug.assert(hand <= 8);
            for ([_]Direction{ .Left, .Up, .Right, .Down }) |direction| {
                const ray = bitboard.ray(n, direction, index);
                const wall_hits = walls & ray;
                if (wall_hits == 0) continue;
                const distance = bitboard.distanceToClosest(n, direction, wall_hits, index);
                const all_hits = state.noble & ray;
                if (all_hits != 0) { // check for capstone blocking
                    const cap_distance = bitboard.distanceToClosest(n, direction, all_hits, index);
                    if (cap_distance < distance) continue;
                }
                smashes += lut.smashes[hand - 1][distance];
            }
        }
        break :blk smashes;
    };

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

        const p1 = try tps.parse(n, start_pos);
        const p2 = try tps.parse(n, corner_opening);
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

test "countMoves capstone blocking smash" {
    const p5 = .{ "x5/x5/2S,211C,2C,212S,x/x5/x5 1 7", 55 };
    const p6 = .{ "x6/x4,1S,x/x2,21111S,1C,22122C,x/x6/x6/x6 2 11", 95 };
    const p7 = .{ "x7/1C,1112S,x,112211C,2S,2C,1S/x7/x3,222C,x3/x3,2S,x3/x3,1S,x3/x7 1 10", 112 };
    const p8 = .{ "x,1S,1C,1S,x4/1,11,11111C,2S,2C,2S,2S,2S/x8/x8/x2,2C,x5/x2,1S,x5/x2,1S,x5/x2,1S,x5 1 14", 148 };
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

test "countMoves equal to countPositionsRec" {
    const positions = .{
        .{ 3, "2,1,1/2221,2S,1/x,2,2S 1 8" },
        .{ 3, "1,2,x/22,111S,2/2S,x,21 2 8" },
        .{ 4, "x,1,1,2/2,221S,2,1/2,22121,x,2S/1,2,1S,x 1 14" },
        .{ 4, "2,1,2,x/2S,12,1S,1/1,1,2112,2/x,1,2,x 2 11" },
        .{ 5, "x,1212,1,1,x/2,x,1112S,1,x/12C,21C,12,2,1/1S,21212,x,221S,2/2,x,21,x,2 1 28" },
        .{ 5, "2,x4/2,x,21S,x,1/22,122,1S,1,12S/12C,11C,121,12121121,1S/1,12S,1,1S,2S 2 29" },
        .{ 6, "21,22,x2,2,x/x,222S,2S,x,1,21S/11S,x,2211,1S,2S,1111122/211,1,x,2,2C,2/2121,1221S,11C,1212S,211122S,x/21,x,1,2S,x2 2 30" },
        .{ 6, "2,2S,x,22,x,11/12C,1S,x2,11S,x/22S,x2,1211211,1S,22/21S,221,x,22S,1222S,2/2,x2,2S,121,121221/211S,1C,11211S,12,2S,11 1 31" },
        .{ 7, "2,2,x2,1,1222221S,x/21,2,2,21,x3/2,1,2,222221C,1,x,2/2,x,12S,2,2,2111112C,1111112S/12,x2,1,2,x,11111112C/21C,122222112S,x,1,1,x2/2,x2,1221,1,1,121 1 77" },
        .{ 7, "2,2,1,2,2,2,x/x,2,1,1,222221C,2,2/1,21,221C,2,1112C,1,1/1,x2,1111121212C,1,1,x/221S,1,x,2,2,2,x/x,112S,1111221S,1,1,21,x/x,1,x2,22,212,1 2 59" },
        .{ 8, "2,2,22221C,x,2,2,1S,1/2,212,2S,x,21,2,1,2S/2,2,2C,11,x2,21S,21/2,1,x,112212C,12,221S,2,1/2,2,21S,2,22121S,12,12,1112/21,221C,2S,2,1,112,2,1112/2,1,1,1,x3,1/2,12,x,1,x,1,1,12 1 73" },
        .{ 8, "2,2,212,2,22221C,2,2,1/2,2,2,21S,22,111212C,2,21/12,x,12,2,1S,2,2,21/12,122,2221S,21S,x,2,1,1/211112S,1S,2,2,x,1C,1,x/x,12,21S,2,1,1,x2/1S,12,x,2,1112112C,x3/x2,12,1112,1,1,1,1 2 79" },
    };
    inline for (positions) |p| {
        const n = p.@"0";
        const tps_string = p.@"1";
        var state = try tps.parse(n, tps_string);
        try std.testing.expectEqual(countMoves(n, &state), countPositionsRec(n, &state, 0));
    }
}

fn testPerft(n: comptime_int, tps_str: []const u8, results: []const u64) !void {
    var state = try tps.parse(n, tps_str);
    for (results, 0..) |r, depth| {
        const before = state;
        const positions = countPositions(n, &state, @truncate(depth));
        try std.testing.expectEqual(before, state);
        try std.testing.expectEqual(r, positions);
    }
}

test "countPositions openings" {
    try testPerft(3, "x3/x3/x3 1 1", &[_]u64{ 1, 9, 72, 1200, 17792, 271812, 3712952, 52364896, 679639648, 9209357840 });
    try testPerft(4, "x4/x4/x4/x4 1 1", &[_]u64{ 1, 16, 240, 7440, 216464, 6468872, 181954216, 5231815136 });
    try testPerft(5, "x5/x5/x5/x5/x5 1 1", &[_]u64{ 1, 25, 600, 43320, 2999784, 187855252, 11293470152 });
    try testPerft(6, "x6/x6/x6/x6/x6/x6 1 1", &[_]u64{ 1, 36, 1260, 132720, 13586048, 1253506520 });
    try testPerft(7, "x7/x7/x7/x7/x7/x7/x7 1 1", &[_]u64{ 1, 49, 2352, 339696, 48051008, 6813380628 });
    try testPerft(8, "x8/x8/x8/x8/x8/x8/x8/x8 1 1", &[_]u64{ 1, 64, 4032, 764064, 142512336, 26642455192 });
}

test "countPositions complicated" {
    try testPerft(6, "x,2,2,22S,2,111S/21S,22C,112,x,1112S,11S/x,2,112212,2,2S,2/x,2,121122,x,1112,211/21C,x,1,2S,21S,x/2S,x,212,1S,12S,1S 1 33", &[_]u64{ 1, 56, 17322, 1419637, 280504959 });
    try testPerft(6, "x2,2,22,2C,1/21221S,1112,x,2211,1,2/x2,111S,x,11S,12S/11S,1S,2S,2,12S,1211C/x,12S,2,122S,x,212S/12,x2,1S,22222S,21121 2 31", &[_]u64{ 1, 108, 11169, 991034, 92392763 });
    try testPerft(6, "2,x,2,111S,2,12/2,122S,2122,1S,x,1/x,111,1,11S,x2/21122112C,x,212S,2S,2,1212S/1,112S,21221S,2S,x2/21,222,x,12S,x2 2 30", &[_]u64{ 1, 197, 15300, 2616619, 215768669 });
    try testPerft(7, "1,x2,22S,1,x2/1,2S,122,1S,1,12,22/2,1,x,2,1221C,11S,21/x,1211S,221,1,12122S,121,1/2,122C,212111,1S,22,12,1/2S,2,x,12122,2,21,2S/x2,1S,1,2,1,2 2 41", &[_]u64{ 1, 203, 43807, 9102472, 1944603576 });
    try testPerft(7, "1,1,x5/x,12,1S,111,2S,211,2/12S,2,1C,21212S,212,21,2C/x,211S,122,2221,21,22,1/x,1,221,12,1,1,1112S/x,1,12222S,2,222,112121S,122/1,x,1,x,2,12,11S 2 41", &[_]u64{ 1, 253, 63284, 16374739, 3821510016 });
    try testPerft(8, "2S,1S,2S,1S,2S,1S,2S,1S/1S,2S,1S,2S,1S,2S,1S,2S/2S,1S,2S,1S,2S,1S,2S,1S/1S,2S,1S,111222111C,x,2S,1S,2S/2S,1S,2S,x,222111222C,1S,2S,1S/1S,2S,1S,2S,1S,2S,1S,2S/2S,1S,2S,1S,2S,1S,2S,1S/1S,2S,1S,2S,1S,2S,1S,2S 2 40", &[_]u64{ 1, 42, 1298, 11632, 223448, 4623236, 131138098 });
    try testPerft(8, "x,1,1,1S,1S,1S,1S,1S/1,x,1,1,2S,2S,1C,1S/1,1,x,1,1,2C,2S,1S/1S,1,1,x,1,1,2S,1S/1S,2S,1,1,x,1,1,1S/1S,2S,2C,1,1,x,1,1/1S,1C,2S,2S,1,1,x,1/1S,1S,1S,1S,1S,1,1,x 2 50", &[_]u64{ 1, 32, 3400, 92372, 9968672, 362489760 });
}

test "max stacks" {
    try testPerft(3, "x3/x,111222111222111222,x/x3 2 10", &[_]u64{ 1, 28, 216, 1224, 13272, 167800, 2089168, 30987564, 440734112 });
    try testPerft(4, "x4/x4/x2,1112221112221112221112221122,x/x4 2 15", &[_]u64{ 1, 58, 1218, 25386, 738000, 23882138, 849534662 });
    try testPerft(5, "x5/x5/x2,111222111222111222111222111222111222111222C,x2/x5/x5 2 22", &[_]u64{ 1, 108, 3788, 238084, 9144928, 662018600 });
    try testPerft(6, "x6/x6/x6/x3,111222111222111222111222111222111222111222111222111222111222C,x2/x6/x6 2 31", &[_]u64{ 1, 194, 11404, 967906, 57444230, 6455421350 });
    try testPerft(7, "x7/x7/x7/x3,111222111222111222111222111222111222111222111222111222111222111222111222111222121C,x3/x7/x7/x7 1 41", &[_]u64{ 1, 300, 34732, 6229260, 76222701 });
    try testPerft(8, "x8/x8/x8/x8/x4,11122211122211122211122211122211122211122211122211122211122211122211122211122211122211122211122212121C,x3/x8/x8/x8 1 51", &[_]u64{ 1, 571, 159677, 51730041, 12911772483 });
}

test "countPositions capstone blocking smash" {
    try testPerft(5, "x5/x5/2S,211C,2C,212S,x/x5/x5 1 7", &[_]u64{ 1, 55, 3314, 175900, 10062310, 516323231 });
    try testPerft(6, "x6/x4,1S,x/x2,21111S,1C,22122C,x/x6/x6/x6 2 11", &[_]u64{ 1, 95, 11683, 1035124, 111863932 });
    try testPerft(7, "x7/1C,1112S,x,112211C,2S,2C,1S/x7/x3,222C,x3/x3,2S,x3/x3,1S,x3/x7 1 10", &[_]u64{ 1, 112, 14248, 1693182, 207813633 });
    try testPerft(8, "x,1S,1C,1S,x4/1,11,11111C,2S,2C,2S,2S,2S/x8/x8/x2,2C,x5/x2,1S,x5/x2,1S,x5/x2,1S,x5 1 14", &[_]u64{ 1, 148, 16516, 2446613, 272421987 });
}
