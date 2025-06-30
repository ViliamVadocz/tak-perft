const state = @import("state.zig");

pub fn Reserves(n: comptime_int) type {
    state.assertSize(n);
    return switch (n) {
        3 => packed struct { caps: u0 = 0, flats: u4 = 10 },
        4 => packed struct { caps: u0 = 0, flats: u4 = 15 },
        5 => packed struct { caps: u1 = 1, flats: u5 = 21 },
        6 => packed struct { caps: u1 = 1, flats: u5 = 30 },
        7 => packed struct { caps: u2 = 2, flats: u6 = 40 },
        8 => packed struct { caps: u2 = 2, flats: u6 = 50 },
        else => unreachable,
    };
}
