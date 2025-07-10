const state = @import("state.zig");

pub fn Reserves(n: comptime_int) type {
    state.assertSize(n);
    return switch (n) {
        3 => packed struct { flats: u4 = 10, caps: u0 = 0 },
        4 => packed struct { flats: u4 = 15, caps: u0 = 0 },
        5 => packed struct { flats: u5 = 21, caps: u1 = 1 },
        6 => packed struct { flats: u5 = 30, caps: u1 = 1 },
        7 => packed struct { flats: u6 = 40, caps: u2 = 2 },
        8 => packed struct { flats: u6 = 50, caps: u2 = 2 },
        else => unreachable,
    };
}

test "reserves fit in u8" {
    const std = @import("std");
    inline for (state.min_n..state.max_n + 1) |n| {
        try std.testing.expect(@bitSizeOf(Reserves(n)) <= @bitSizeOf(u8));
    }
}
