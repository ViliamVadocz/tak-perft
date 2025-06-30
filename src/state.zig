const std = @import("std");

const BitBoard = @import("bitboard.zig").BitBoard;
const Color = @import("color.zig").Color;
const Reserves = @import("reserves.zig").Reserves;
const Stack = @import("stack.zig").Stack;

pub const min_n = 3;
pub const max_n = 8;

pub fn assertSize(n: comptime_int) void {
    switch (n) {
        min_n...max_n => return,
        else => @compileError("Unsupported board size."),
    }
}

pub fn State(n: comptime_int) type {
    assertSize(n);
    return struct {
        stacks: [n * n]Stack(n) = @splat(Stack(n).init()),
        player: Color = .White,

        noble: BitBoard(n) = 0,
        road: BitBoard(n) = 0,
        white: BitBoard(n) = 0,
        black: BitBoard(n) = 0,

        white_reserves: Reserves(n) = .{},
        black_reserves: Reserves(n) = .{},

        pub fn init() State(n) {
            return .{};
        }

        pub fn opening(self: State(n)) bool {
            if (@popCount(self.road) > 1) return false;
            const starting: Reserves(n) = .{};
            const white_flats = starting.flats - self.white_reserves.flats;
            const black_flats = starting.flats - self.black_reserves.flats;
            return white_flats == 0 and black_flats < 2;
        }

        pub fn currentReserves(self: State(n)) Reserves(n) {
            return switch (self.player) {
                .White => self.white_reserves,
                .Black => self.black_reserves,
            };
        }

        pub fn currentPieces(self: State(n)) BitBoard(n) {
            return switch (self.player) {
                .White => self.white,
                .Black => self.black,
            };
        }
    };
}
