const std = @import("std");
const parseUnsigned = std.fmt.parseUnsigned;
const splitScalar = std.mem.splitScalar;

const Bitboard = @import("bitboard.zig").BitBoard;
const Color = @import("color.zig").Color;
const Reserves = @import("reserves.zig").Reserves;
const Stack = @import("stack.zig").Stack;
const state = @import("state.zig");
const State = state.State;
const zobrist = @import("zobrist.zig");

pub fn determineSize(tps: []const u8) ?u8 {
    var count: u8 = 1;
    for (tps) |char| {
        if (char == '/') count += 1;
    }
    if (count < state.min_n) return null;
    if (count > state.max_n) return null;
    return count;
}

pub const ParseTPSError = error{
    EmptyTps,
    InvalidPlayerNumber,
    TwoSlashesAfterEachOther,
    TwoCommasAfterEachOther,
    MissingNumbersInStack,
    InvalidColorInStack,
    WrongNumberOfItemsInRow,
};

pub fn parse(n: comptime_int, tps: []const u8) (ParseTPSError || std.fmt.ParseIntError)!State(n) {
    state.assertSize(n);
    if (tps.len == 0) return error.EmptyTps;
    var split_by_spaces = splitScalar(u8, tps, ' ');
    const board = split_by_spaces.next().?;
    const player_number = try parseUnsigned(u4, split_by_spaces.next() orelse "1", 10);
    // const move_number = try parseUnsigned(u32, split_by_spaces.next() orelse "1", 10);

    var out = State(n).init();
    out.player = switch (player_number) {
        1 => .White,
        2 => .Black,
        else => return error.InvalidPlayerNumber,
    };

    var rows = splitScalar(u8, board, '/');
    var index: usize = 0;
    var bit: Bitboard(n) = 1;

    while (rows.next()) |row| {
        if (row.len == 0) return error.TwoSlashesAfterEachOther;
        const before_row = index;
        var items = splitScalar(u8, row, ',');
        while (items.next()) |item| {
            if (item.len == 0) return error.TwoCommasAfterEachOther;
            // empty squares
            if (item[0] == 'x') {
                const amount = if (item.len == 1) 1 else try parseUnsigned(u4, item[1..], 10);
                index += amount;
                bit <<= amount;
                continue;
            }
            // top piece
            const last_piece = item[item.len - 1];
            var road = true;
            var noble = false;
            if (last_piece == 'S') {
                road = false;
                noble = true;
            } else if (last_piece == 'C') {
                noble = true;
            }
            if (noble) out.noble |= bit;
            if (road) out.road |= bit;
            // stack
            const stack_numbers = if (noble) item[0 .. item.len - 1] else item;
            if (stack_numbers.len == 0) return error.MissingNumbersInStack;
            const stack = &out.stacks[index];
            for (stack_numbers, 1..) |number, i| {
                const color: Color = switch (number) {
                    '1' => .White,
                    '2' => .Black,
                    else => return error.InvalidColorInStack,
                };
                stack.add_one(color);
                // reserves
                const last = i == stack_numbers.len;
                const reserves = switch (color) {
                    .White => &out.white_reserves,
                    .Black => &out.black_reserves,
                };
                if (last and road and noble) {
                    if (@TypeOf(reserves.caps) != u0) {
                        reserves.caps -|= 1;
                    }
                } else {
                    reserves.flats -|= 1;
                }
            }
            switch (stack.top()) {
                .White => out.white |= bit,
                .Black => out.black |= bit,
            }
            index += 1;
            bit <<= 1;
        }
        if (index - before_row != n) return error.WrongNumberOfItemsInRow;
    }

    out.hash = zobrist.getHash(n, out);
    return out;
}

test "parse errors" {
    try std.testing.expectError(error.EmptyTps, parse(3, ""));
    try std.testing.expectError(error.InvalidColorInStack, parse(3, "x3/123,x2/x3 1 10"));
    try std.testing.expectError(error.InvalidPlayerNumber, parse(3, "x3/x3/x3 3 10"));
    try std.testing.expectError(error.MissingNumbersInStack, parse(3, "x3/S,x2/x3 1 10"));
    try std.testing.expectError(error.TwoCommasAfterEachOther, parse(3, "x3/x,x,,x/x3 1 10"));
    try std.testing.expectError(error.TwoSlashesAfterEachOther, parse(3, "x3//x3/x3 1 10"));
    try std.testing.expectError(error.WrongNumberOfItemsInRow, parse(3, "x4/x3/x3 1 10"));
}
