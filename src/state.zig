const std = @import("std");

const bitboard = @import("bitboard.zig");
const BitBoard = bitboard.BitBoard;
const Color = @import("color.zig").Color;
const Reserves = @import("reserves.zig").Reserves;
const Stack = @import("stack.zig").Stack;
const tps = @import("tps.zig");
const zobrist = @import("zobrist.zig");
const HashType = zobrist.HashType;

pub const min_n = 3;
pub const max_n = 8;

/// Assert at compile time that the function is using the supported sizes.
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
        black: BitBoard(n) = 0, // TODO: Remove? `black = (noble | road) & ~white`

        // NOTE:
        // capstones = noble & road
        // walls = noble & ~road

        white_reserves: Reserves(n) = .{},
        black_reserves: Reserves(n) = .{},

        hash: HashType = zobrist.board_size[n],

        pub fn init() State(n) {
            return .{};
        }

        /// Check whether the state is internally consistent.
        ///
        /// An example of when this function would fail is when
        /// the number of reserves depleted does not match the
        /// number of pieces on the board according to the stacks.
        pub fn checkInvariants(self: State(n)) void {
            const mode = comptime @import("builtin").mode;
            if (mode != .Debug and mode != .ReleaseSafe) return;
            // count used pieces and recompute bitboards
            var white_flats: u8 = 0;
            var black_flats: u8 = 0;
            var white: BitBoard(n) = 0;
            var black: BitBoard(n) = 0;
            for (self.stacks, 0..) |stack, i| {
                const bit = @as(BitBoard(n), 1) << @truncate(i);
                const size = stack.size();
                if (size == 0) continue;
                switch (stack.top()) {
                    .White => white |= bit,
                    .Black => black |= bit,
                }
                var copy = stack;
                const full = @divFloor(size, 8);
                for (0..full) |_| {
                    const colors = copy.take(8);
                    const set = @popCount(colors);
                    white_flats += 8 - set;
                    black_flats += set;
                }
                const remaining = copy.size();
                std.debug.assert(remaining < 8);
                var colors = copy.take(@truncate(remaining));
                std.debug.assert(copy._colors == 1);
                for (0..remaining) |_| {
                    switch (colors & 1) {
                        0 => white_flats += 1,
                        1 => black_flats += 1,
                        else => unreachable,
                    }
                    colors >>= 1;
                }
            }
            // adjust counts for capstones
            const caps = self.noble & self.road;
            const white_caps = @popCount(caps & self.white);
            const black_caps = @popCount(caps & self.black);
            white_flats -= white_caps;
            black_flats -= black_caps;

            // check bitboards
            std.debug.assert(self.white == white);
            std.debug.assert(self.black == black);
            std.debug.assert(self.white & self.black == 0);
            std.debug.assert(self.white | self.black == self.road | self.noble);
            std.debug.assert(@popCount(self.road & self.noble) == white_caps + black_caps);
            // check reserves
            const default_reserves = Reserves(n){};
            std.debug.assert(self.white_reserves.flats + white_flats == default_reserves.flats);
            std.debug.assert(self.black_reserves.flats + black_flats == default_reserves.flats);
            std.debug.assert(self.white_reserves.caps + white_caps == default_reserves.caps);
            std.debug.assert(self.black_reserves.caps + black_caps == default_reserves.caps);
            // check hash
            std.debug.assert(self.hash == zobrist.getHash(n, self));
        }

        /// Check if it is the opening (first two plies).
        /// We check based on placed flats.
        pub fn opening(self: State(n)) bool {
            if (@popCount(self.road) > 1) return false;
            const starting: Reserves(n) = comptime .{};
            const white_flats = starting.flats - self.white_reserves.flats;
            const black_flats = starting.flats - self.black_reserves.flats;
            return white_flats == 0 and black_flats < 2;
        }

        /// Get reserves (current player, other player).
        pub fn reserves(self: State(n)) struct { Reserves(n), Reserves(n) } {
            return switch (self.player) {
                .White => .{ self.white_reserves, self.black_reserves },
                .Black => .{ self.black_reserves, self.white_reserves },
            };
        }

        /// Get mutable reserves (current player, other player).
        pub fn reserves_mut(self: *State(n)) struct { *Reserves(n), *Reserves(n) } {
            return switch (self.player) {
                .White => .{ &self.white_reserves, &self.black_reserves },
                .Black => .{ &self.black_reserves, &self.white_reserves },
            };
        }

        /// Get piece bitboards (current player, other player).
        pub fn pieces(self: State(n)) struct { BitBoard(n), BitBoard(n) } {
            return switch (self.player) {
                .White => .{ self.white, self.black },
                .Black => .{ self.black, self.white },
            };
        }

        /// Get mutable piece bitboards (current player, other player).
        pub fn pieces_mut(self: *State(n)) struct { *BitBoard(n), *BitBoard(n) } {
            return switch (self.player) {
                .White => .{ &self.white, &self.black },
                .Black => .{ &self.black, &self.white },
            };
        }

        /// Check if this is a terminal state.
        pub fn terminal(self: State(n)) bool {
            if ((self.white | self.black) == std.math.maxInt(BitBoard(n))) return true;
            if ((self.white_reserves.flats == 0 and self.white_reserves.caps == 0) or
                (self.black_reserves.flats == 0 and self.black_reserves.caps == 0)) return true;

            // TODO: Cache this?
            // road detection
            const white_road = self.white & self.road;
            const black_road = self.black & self.road;
            var white_left = white_road & bitboard.colBoardAt(n, n - 1);
            var white_right = white_road & bitboard.colBoardAt(n, 0);
            // white horizontal
            while (true) {
                const new_white_left = white_road & bitboard.spread(n, white_left);
                const new_white_right = white_road & bitboard.spread(n, white_right);
                if (white_left == new_white_left or white_right == new_white_right) break;
                if (new_white_left & new_white_right != 0) return true;
                white_left = new_white_left;
                white_right = new_white_right;
            }
            var white_up = white_road & bitboard.rowBoardAt(n, n - 1);
            var white_down = white_road & bitboard.rowBoardAt(n, 0);
            // white vertical
            while (true) {
                const new_white_up = white_road & bitboard.spread(n, white_up);
                const new_white_down = white_road & bitboard.spread(n, white_down);
                if (white_up == new_white_up or white_down == new_white_down) break;
                if (new_white_up & new_white_down != 0) return true;
                white_up = new_white_up;
                white_down = new_white_down;
            }
            var black_left = black_road & bitboard.colBoardAt(n, n - 1);
            var black_right = black_road & bitboard.colBoardAt(n, 0);
            // black horizontal
            while (true) {
                const new_black_left = black_road & bitboard.spread(n, black_left);
                const new_black_right = black_road & bitboard.spread(n, black_right);
                if (black_left == new_black_left or black_right == new_black_right) break;
                if (new_black_left & new_black_right != 0) return true;
                black_left = new_black_left;
                black_right = new_black_right;
            }
            var black_up = black_road & bitboard.rowBoardAt(n, n - 1);
            var black_down = black_road & bitboard.rowBoardAt(n, 0);
            // black vertical
            while (true) {
                const new_black_up = black_road & bitboard.spread(n, black_up);
                const new_black_down = black_road & bitboard.spread(n, black_down);
                if (black_up == new_black_up or black_down == new_black_down) break;
                if (new_black_up & new_black_down != 0) return true;
                black_up = new_black_up;
                black_down = new_black_down;
            }

            return false;
        }
    };
}

test "random nonterminal" {
    const positions = .{
        "2S,x2,111S,12S,x/221S,1,1S,21C,2222S,122/1211,2S,11,211S,222S,1/x,2C,1S,112S,221,12S/2,1S,22S,2S,x2/1,21,12,x,21,12S 2 30",
        "212S,1,11S,11S,2,x/x4,11,x/2S,211121211S,21222S,1C,21S,x/12111,1S,121,2S,x,2/2,22S,22,22,1,12222/x,1S,1212S,1,x2 2 30",
        "2212,x,2S,x,2,2S/12,2S,2S,1122,1S,121122C/1,212S,1,x,2S,12111/x,22211S,x,2,2,11/x,1S,1C,x2,212/221,x,2S,11111211S,2,x 1 31",
        "221S,x2,122221S,1122222C,2S/x,22222,22,22,1S,1/x,2,11S,x,1211,x/2S,1,x,21S,x,11/x2,1212,111S,x2/1S,1121C,1S,11S,x,112 1 31",
        "11,1,2S,111S,2222S,1S/21S,2,x,2S,1S,111S/x,211S,2S,212,2112,1C/1S,1S,1S,1S,12S,2S/1,22S,x,2,11,12212/2S,x2,222,22S,21S 1 30",
        "x2,2221S,2S,1121S,2S/x,1S,x,222,1S,12/x,2,x3,12212221C/2S,211,2S,x,21,12/1221S,1S,x2,1S,21212C/1,111,222S,1,1,1111 1 31",
        "1,11,x,212,12,12222S/1212S,2S,22S,2111,1,x/2,x,11,122,212S,1C/12,21S,2C,21,22,1S/12S,x,211,1,x,212S/2,x2,1,12S,1 1 31",
        "1,12112S,x,11121S,21S,2/2,222,2,221S,x,21S/22S,1,11S,2112,2,1222211/x2,2S,11S,21S,1/x,1,12S,x,2,x/x2,1S,x,11122C,221S 2 31",
        "x,122C,x,122,2221,1/1,1,1,1S,111,1S/1S,211S,12S,21S,x,1S/1211S,2S,2S,212,1S,12122S/221S,x,211,x,122222S,x/x2,2S,2S,2S,21 2 31",
    };
    inline for (positions) |p| {
        const state = try tps.parse(6, p);
        try std.testing.expect(!state.terminal());
    }
}

test "random depleted reserves" {
    const positions = .{
        "121,112,1,1,1111S,2112/11S,x,1,x3/2S,x,2C,1,121222S,2211S/2,1,x,12122,121,x/22S,1212S,x,2,1C,11/2S,222S,222,2S,2,x 1 32",
        "2111,122,2S,x3/2,x,22121S,1211121,x2/12S,2S,1S,222S,2122S,1122S/x,2S,x2,2S,122C/x,1S,2211111,x,11,1/x,2221S,21,1,x,21S 1 32",
        "x,2,1,1S,21,22S/221S,1,12S,2,x,1S/1S,1111,22211S,x,2S,122C/221,x2,1C,x,1/122,21121S,x,211212112S,x,1/2,12,2,x,211,2 2 31",
        "x,2S,x,22121S,2111,x/112C,x,2S,122,x,1/x,2,21S,2S,1S,12/1222121S,2S,x,121S,x,1S/22,22211122,12S,22,x,1S/1,1S,1C,21112S,x2 1 31",
        "1211,11C,21,2S,1S,1221122222S/222,2,2,122S,1S,1/111S,221,2,2C,2S,2/x3,1S,12S,2/x,21,1,11,x,1S/21111,21,x2,21S,12S 2 31",
        "11,x,212S,121,11S,12S/x4,2,2/1,22,2112,21S,21S,112/122S,1,122S,111,x2/x,21,12C,22,2122,1S/1S,1S,22,x,2222,211S 1 31",
    };
    inline for (positions) |p| {
        const state = try tps.parse(6, p);
        try std.testing.expect(state.terminal());
    }
}

test "random board fill" {
    const positions = .{
        "2,1,2,1,1S,1/11,2C,2S,111S,21111,21S/2,2S,1S,2S,12,21/2S,21111212S,2,22,112S,2S/1,2,1S,22S,22S,1S/2S,1S,22S,1,1C,22 2 34",
        "1,11,22112S,212S,1,2/1,2,2,12,1,2/1S,21,1,1,1S,22S/1,12,21,221,2211S,2/2S,21,2C,1,211C,2/2,1,2,1122,1,12 2 39",
        "2,11C,122S,2S,1,2S/1,11,1,1S,2,222S/21S,22,2S,22S,11,11/21S,2,11S,221S,11S,2S/1,21,1,121,2S,2/1S,222S,21,12,1,1 2 34",
        "212,1,2,1C,2,1211S/1S,2S,2,12C,2,1/2,1S,2,1S,2S,21/1,2,1S,1,2,1/112,12,112S,21,21,12/11,1,1,1S,22212,22222S 2 35",
        "2,22,1,2,1,11/21212S,221S,21,1,21222S,2/2S,1S,1S,2,2,12/122S,1,1,21,1,12S/2,11,11,1,21C,1/2,221,1,2S,2,1 2 38",
    };
    inline for (positions) |p| {
        const state = try tps.parse(6, p);
        try std.testing.expect(state.terminal());
    }
}

test "random road" {
    const positions = .{
        "2S,211211C,x,1,2,12S/x2,1S,2S,2C,21S/x,122S,1S,x,12,122/x2,11,1S,22S,2/x2,11S,22S,21S,11112/1221222S,1,x,22122,11S,2 2 32",
        "1,1,221,112,1S,x/1222,2C,11,1,1S,1S/1C,22,1,11,2,2/2S,1S,221,221S,2S,x/x,21S,1,21,2,x/x,1S,21221212212221,1S,1S,x 2 33",
        "1211S,121S,212,x2,111S/1,211S,2C,1C,22S,212S/221,211S,2,x,2,x/22,2,2,2S,1S,1S/2,x,11,12,1,1S/112,1S,2,x,1112,22S 1 31",
        "1,x3,221,111S/222S,12,2,112,212C,1/2,2,1,2S,2,21S/2S,1,2S,1,12,12122112/21S,12,2S,1,2122211C,x/x,1S,11,x,12,x 1 35",
        "2,2,112,2,21,1S/x2,2,21221,2S,x/2S,1,22,1,211121C,22/122S,x,2,x,1,1S/11,2S,2,12,112,122C/1211S,11,122S,1,x,2S 1 34",
    };
    inline for (positions) |p| {
        const state = try tps.parse(6, p);
        try std.testing.expect(state.terminal());
    }
}

test "max road" {
    const positions = .{
        .{ 3, "x,2,1/1,2,2/1,x,2 1 5" },
        .{ 3, "1,1,2/2,1,1/2,x,2 2 5" },
        .{ 4, "x2,1112,1/1S,1S,112,1/1,2,2,1S/2,2,x2 1 12" },
        .{ 4, "x2,1,1/x2,1,x/1,1,1,x/x4 1 6" },
        .{ 5, "x4,2/x,2,2,2,2/x,2,x3/x,2,2,2,2/x4,2 2 12" },
        .{ 5, "1,1,x,1,1/x,1,x,1,x/x,1,x,1,x/x,1,1,1,x/x5 1 11" },
        .{ 6, "2,2,2,2,2,x/x4,2,x/x,2,2,2,2,x/x,2,x4/x,2,2,2,2,2/x6 2 16" },
        .{ 6, "x,1,x4/x,1,x,1,1,1/x,1,x,1,x,1/x,1,x,1,x,1/x,1,1,1,x,1/x5,1 1 16" },
        .{ 7, "x,1,x5/1,1,x,1,1,1,x/1,x,1,1,x,1,x/1,x,1,x,1,1,x/1,x,1,x,1,x2/1,1,1,x,1,1,x/x5,1,x 1 24" },
        .{ 7, "2C,1,1,1,1,1,1/1,2,2,2,2,x,1/1,2,x2,2,2,2/1,2,2,x3,1/1,x,2,2,2,2,1/2,2,x3,2,1/1,2,2,2,2,2,1 1 1" },
        .{ 8, "x,1,1,1,1,1,1,x/1,1,x4,1,x/x2,1,1,1,x,1,x/x,1,1,x,1,x,1,x/x,1,x2,1,1,1,x/x,1,x6/x,1,1,1,1,1,1,1/x8 1 32" },
        .{ 8, "x,2,x,2,x3,2/x,2,2,x,2,2,2,x/x2,2,x,2,x,2,2/x,2,2,x,2C,2,x,2/x,2,x,2,x,2,x,2/x,2,2C,x,2,2,x,2/2,x,2,2,2,x,2,2/2,2,x3,2,2,x 2 38" },
    };
    inline for (positions) |p| {
        const state = try tps.parse(p.@"0", p.@"1");
        try std.testing.expect(state.terminal());
    }
}
