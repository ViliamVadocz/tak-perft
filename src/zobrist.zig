const std = @import("std");
const state = @import("state.zig");
const State = state.State;
const bitboard = @import("bitboard.zig");
const BitBoard = bitboard.BitBoard;
const BitBoardIndex = bitboard.BitBoardIndex;
const Color = @import("color.zig").Color;

pub const HashType = u64;
const max_amount = state.max_n; // most that can be picked up from a stack
const max_board_size = state.max_n * state.max_n;
const max_height = 101; // refer to calculation in stack.zig

pub const player_black = 5948797944002618758; // TODO: Experiment
pub const capstone = blk: {
    @setEvalBranchQuota(2_000);
    const seed = 9622543866434868678; // TODO: Experiment with seeds
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    var lut: [max_board_size]HashType = undefined;
    for (0..max_board_size) |i| {
        lut[i] = rand.int(HashType);
    }
    break :blk lut;
};
pub const wall = blk: {
    @setEvalBranchQuota(2_000);
    const seed = 15536116614583780634; // TODO: Experiment with seeds
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    var lut: [max_board_size]HashType = undefined;
    for (0..max_board_size) |i| {
        lut[i] = rand.int(HashType);
    }
    break :blk lut;
};
pub const stack_color = blk: {
    @setEvalBranchQuota(1_000_000);
    const seed = 3911426766083215428; // TODO: Experiment with seeds
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    var lut: [2][max_height][max_board_size]HashType = undefined;
    for (0..2) |color| {
        for (0..max_height) |i| {
            for (0..max_board_size) |ii| {
                lut[color][i][ii] = rand.int(HashType);
            }
        }
    }
    break :blk lut;
};

pub const optimized_stack_max_height = 16; // limit this optimization to small stacks
const StackChangeType = [optimized_stack_max_height][1 << (max_amount + 1)][max_board_size]HashType;
pub const stack_change: *const StackChangeType = @ptrCast(@alignCast(@embedFile("zobrist_stack_change")));

/// We generate the stack_change LUT as a separate build step since we want
/// to have it done during compilation, but the normal comptime execution is
/// too slow. Instead we compile just this file and run it, saving the LUT
/// to a file. That file then gets embedded into the final binary (see above).
pub fn main() !void {
    var arena_state = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_state.deinit();

    const args = try std.process.argsAlloc(arena_state.allocator());
    std.debug.assert(args.len == 2);

    var output_file = try std.fs.cwd().createFile(args[1], .{});
    defer output_file.close();
    const lut = makeStackChange();
    try output_file.writeAll(@ptrCast(&lut));
}

fn makeStackChange() StackChangeType {
    var lut: StackChangeType = undefined;
    for (0..optimized_stack_max_height) |height| {
        lut[height][0] = @splat(0); // never accessed, but better to be safe than sorry
        lut[height][1] = @splat(0); // invalid amount, but used for dynamic programming
        for (2..(1 << (max_amount + 1))) |pattern| {
            for (0..max_board_size) |i| {
                const color = pattern & 1;
                const amount = @bitSizeOf(@TypeOf(pattern)) - @clz(pattern) - 1;
                const new_height = height + amount;
                lut[height][pattern][i] = lut[height][pattern >> 1][i] ^ stack_color[color][new_height - 1][i];
            }
        }
    }
    return lut;
}

/// Get the Zobrist hash for a state from scratch.
pub fn getHash(n: comptime_int, s: State(n)) HashType {
    state.assertSize(n);
    var hash: u64 = if (s.player == Color.Black) player_black else 0;
    const caps = s.noble & s.road;
    const walls = s.noble & ~s.road;
    for (0..n * n) |i| {
        const stack = s.stacks[i];
        if (stack.size() == 0) continue;
        var colors = stack._colors;
        var height = stack.size();
        while (colors > 1) : (colors >>= 1) {
            height -= 1;
            const color = colors & 1;
            std.debug.assert(color <= 1);
            hash ^= stack_color[@intCast(color)][height][i];
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

// TODO: Check if inlining and branch hints actually do anything
pub inline fn hash_update_after_stack_change(n: comptime_int, stack_height: usize, colors: u8, amount: u4, index: BitBoardIndex(n)) u64 {
    std.debug.assert(amount >= 1);
    std.debug.assert(amount <= 8);
    var hash: u64 = 0;
    if (stack_height < optimized_stack_max_height) {
        @branchHint(.likely);
        const color_pattern = (@as(u9, 1) << amount) | colors;
        hash ^= stack_change[stack_height][color_pattern][index];
    } else {
        @branchHint(.unlikely);
        var iter = colors;
        for (0..amount) |h| {
            const height = stack_height + amount - 1 - h;
            const piece_color = iter & 1;
            iter >>= 1;
            hash ^= stack_color[piece_color][height][index];
        }
    }
    return hash;
}
