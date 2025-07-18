//! Render the following in Typst:
//!
//! = Counting Spreads
//! == Variables
//! - board size $n$
//! - stack size $s$
//! - amount we can pick up $k := min(n, s)$
//! - distance available for spread $d$
//!
//! == Idea
//! We start by picking up $k$ pieces, and then we make a binary choice for each:
//! - drop the piece on the current square
//! - move one stop and drop the piece there
//! We can represent a spread as $k$-bit number (a pattern), where each bit is set
//! when we choose to move (choices start at lowest significant bit). A valid spread
//! has to move at least one stone, so a valid pattern is $>= 1$. We can also choose
//! to move with every since piece,which would give $k$ set bits = $2^k - 1$.
//!
//! When we restrict the distance available, we are essentially restricting how many
//! times we can choose to take a step, so in the binary representation, how many set
//! bits we have in the pattern.
//!
//! == Formula
//! $
//! "spreads"(k, d)
//!   &= sum_(p=1)^(2^k - 1) ["popcnt"(p) <= d] \
//!   &= cases(
//!     2^k - 1 &"if" k <= d,
//!     sum_(p=1)^(2^ k) ["popcnt"(p) <= d] &"else"
//!   )\
//!   &= cases(
//!     2^k - 1 &"if" k <= d,
//!     sum_(i=1)^d binom(k, i) &"else"
//!   )
//! $
//!
//! Since both $k$ and $d$ is bounded by $n$, we can make a LUT for the second case.
//!
//! == Smashing
//!
//! If the stack has a capstone on top, we are able to smash walls, which adds
//! additional ways we can spread. These spreads correspond to all those that reach
//! a distance $d + 1$ and end with a move.
//!
//! $
//! "smashes"(k, d)
//!   &= sum_(p=1)^(2^k - 1) ["popcnt"(p) = d + 1 and k"th bit is set in" p]\
//!   &= sum_(p=2^(k-1))^(2^k - 1) ["popcnt"(p) = d + 1]\
//!   &= binom(k - 1, d)\
//! $

const std = @import("std");
const state = @import("state.zig");

pub const spreads = blk: {
    var lut: [8][8]u8 = @splat(@splat(0));
    for (1..9) |k| {
        for (1..9) |d| {
            lut[k - 1][d - 1] = computeSpreads(k, d);
        }
    }
    break :blk lut;
};

pub const smashes = blk: {
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
