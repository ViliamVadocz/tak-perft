const std = @import("std");
const state = @import("state.zig");
const State = state.State;
const bitboard = @import("bitboard.zig");
const BitBoard = bitboard.BitBoard;

const HashSize = u64;

pub const player = blk: {
    const seed = 5948797944002618758; // TODO: Experiment with seeds
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    break :blk [2]HashSize{ rand.int(HashSize), rand.int(HashSize) };
};
pub const capstone = blk: {
    @setEvalBranchQuota(2_000);
    const seed = 9622543866434868678; // TODO: Experiment with seeds
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    const size = state.max_n * state.max_n;
    var lut: [size]HashSize = undefined;
    for (0..size) |i| {
        lut[i] = rand.int(HashSize);
    }
    break :blk lut;
};
pub const wall = blk: {
    @setEvalBranchQuota(2_000);
    const seed = 15536116614583780634; // TODO: Experiment with seeds
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    const size = state.max_n * state.max_n;
    var lut: [size]HashSize = undefined;
    for (0..size) |i| {
        lut[i] = rand.int(HashSize);
    }
    break :blk lut;
};
const stack_color = blk: {
    @setEvalBranchQuota(1_000_000);
    const seed = 3911426766083215428; // TODO: Experiment with seeds
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    const size = state.max_n * state.max_n;
    const max_height = @bitSizeOf(u128) - 1;
    var lut: [2][max_height][size]HashSize = undefined;
    for (0..2) |color| {
        for (0..max_height) |i| {
            for (0..size) |ii| {
                lut[color][i][ii] = rand.int(HashSize);
            }
        }
    }
    break :blk lut;
};
pub const stack_change = blk: {
    @setEvalBranchQuota(2_000);
    const size = state.max_n * state.max_n;
    const max_height = @bitSizeOf(u128) - 1;
    const max_amount = state.max_n;
    var lut: [max_height - 1][max_amount][1 << max_amount][size]HashSize = undefined;
    for (0..max_height - 1) |height| {
        for (1..max_amount) |amount| {
            for (0..(1 << amount)) |pattern| {
                for (0..size) |i| {
                    var hash = 0;
                    for (0..amount) |h| {
                        const current_height = height + amount - h; // going top to bottom
                        const color = (pattern >> h) & 1;
                        hash ^= stack_color[color][current_height][i];
                    }
                    lut[height][amount - 1][pattern][i] = hash;
                }
            }
        }
    }
    break :blk lut;
};

fn getHash(n: comptime_int, s: State(n)) HashSize {
    state.assertSize(n);
    var hash = player[@intFromEnum(s.player)];
    const caps = s.noble & s.road;
    const walls = s.noble & ~s.road;
    for (0..n * n) |i| {
        var stack = s.stacks[i];
        if (stack.size() == 0) continue;
        while (stack.size() > 0) {
            const color = stack.take(1);
            hash ^= stack_color[color][stack.size()][i];
        }

        // top piece
        std.debug.assert(i < n * n);
        const bit = @as(BitBoard(n), 1) << @truncate(i);
        if (caps & bit != 0) {
            hash ^= capstone[i];
        } else if (walls & bit != 0) {
            hash ^= wall[i];
        }
    }
    return hash;
}

test "zobrist" {
    const tps = @import("tps.zig");
    const s = try tps.parse(8, "x,2,2,x,1,x2,1/x,2,2,1,1,2,x,1/1,1S,2,1,12,x,222221S,1/x,1,2C,222221C,1,12S,1,1/1,1,221C,11112C,1,1,1,1/2,21S,2,2,2,2,2S,1/1,2221C,21112C,2,2,2,21,2222221S/2,2221S,2,12,2,1,21,2 1 76");
    const hash = getHash(8, s);
    std.debug.print("\nhash: {d}\n", .{hash});
}
