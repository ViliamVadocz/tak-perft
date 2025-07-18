const std = @import("std");
const state = @import("state.zig");
const State = state.State;
const bitboard = @import("bitboard.zig");
const BitBoard = bitboard.BitBoard;

const HashType = u64;
const max_amount = state.max_n; // most that can be picked up from a stack
const max_board_size = state.max_n * state.max_n;
const max_height = 101; // refer to calculation in stack.zig

pub const player = blk: {
    const seed = 5948797944002618758; // TODO: Experiment with seeds
    var prng = std.Random.DefaultPrng.init(seed);
    const rand = prng.random();

    break :blk [2]HashType{ rand.int(HashType), rand.int(HashType) };
};
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
const stack_color = blk: {
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

// TODO: Generate the LUT at compile time automatically
// See: https://ziggit.dev/t/build-system-tricks/3531
fn make_stack_change() !void {
    const size = state.max_n * state.max_n;
    var lut: [stack_max_height][1 << (max_amount + 1)][size]HashType = undefined;
    for (0..stack_max_height) |height| {
        lut[height][0] = @splat(0); // never accessed, but better to be safe than sorry
        lut[height][1] = @splat(0); // invalid amount, but used for dynamic programming
        for (2..(1 << (max_amount + 1))) |pattern| {
            for (0..size) |i| {
                const color = pattern & 1;
                const amount = @bitSizeOf(@TypeOf(pattern)) - @clz(pattern);
                const current_height = height + amount;
                lut[height][pattern][i] = lut[height][pattern >> 1][i] ^ stack_color[color][current_height][i];
            }
        }
    }

    const file = try std.fs.cwd().createFile("zobrist.bin", .{});
    defer file.close();

    try file.writeAll(@ptrCast(&lut));
}
// test make_stack_change {
//     try make_stack_change();
// }

pub const stack_max_height = 16; // limit this optimization to small stacks
pub const stack_change: *const [stack_max_height][(1 << (max_amount + 1))][max_board_size]HashType = @ptrCast(@alignCast(@embedFile("zobrist.bin")));

fn getHash(n: comptime_int, s: State(n)) HashType {
    state.assertSize(n);
    var hash = player[@intFromEnum(s.player)];
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

test "zobrist" {
    const tps = @import("tps.zig");
    const s = try tps.parse(8, "x,2,2,x,1,x2,1/x,2,2,1,1,2,x,1/1,1S,2,1,12,x,222221S,1/x,1,2C,222221C,1,12S,1,1/1,1,221C,11112C,1,1,1,1/2,21S,2,2,2,2,2S,1/1,2221C,21112C,2,2,2,21,2222221S/2,2221S,2,12,2,1,21,2 1 76");
    const hash = getHash(8, s);
    std.debug.print("\nhash: {d}\n", .{hash});
    std.debug.print("stack_color: {d} bytes\n", .{@sizeOf(@TypeOf(stack_color))});
    std.debug.print("stack_change: {d} bytes\n", .{@sizeOf(@TypeOf(stack_change.*))});
}
