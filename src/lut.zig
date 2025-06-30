const std = @import("std");
const state = @import("state.zig");

pub const spreads: [8][8]u8 = blk: {
    var lut: [8][8]u8 = @splat(@splat(0));
    for (1..9) |k| {
        for (1..9) |d| {
            lut[k - 1][d - 1] = computeSpreads(k, d);
        }
    }
    break :blk lut;
};

pub const smashes: [8][8]u8 = blk: {
    var lut: [8][8]u8 = @splat(@splat(0));
    for (1..9) |k| {
        for (0..8) |d| { // smashing with dist = 0 is possible
            lut[k - 1][d] = computeSmashes(k, d);
        }
    }
    break :blk lut;
};

fn binom(n: u8, k: u8) u64 {
    if (k > n) return 0;
    if (k == n) return 1;
    const smaller = @min(k, n - k);
    var numerator: u64 = 1;
    var denominator: u64 = 1;
    for (0..smaller) |i| {
        numerator *= n - i;
        denominator *= i + 1;
    }
    return numerator / denominator;
}

fn computeSpreads(k: comptime_int, d: comptime_int) u8 {
    std.debug.assert(k <= state.max_n);
    std.debug.assert(d <= state.max_n);
    if ((k == 0) or (d == 0)) return 0;
    if (k <= d) {
        return (1 << k) - 1;
    } else {
        var sum = 0;
        for (1..(d + 1)) |i| {
            sum += binom(k, i);
        }
        return sum;
    }
}

fn computeSmashes(k: comptime_int, d: comptime_int) u8 {
    std.debug.assert(k <= state.max_n);
    std.debug.assert(d <= state.max_n);
    if (d >= k) return 0; // too far to smash
    return binom(k - 1, d);
}
