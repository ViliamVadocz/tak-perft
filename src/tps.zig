const std = @import("std");
const parseUnsigned = std.fmt.parseUnsigned;
const splitScalar = std.mem.splitScalar;

const game = @import("game.zig");
const Game = game.Game;
const BitBoard = game.BitBoard;
const Color = @import("color.zig").Color;
const Stack = @import("stack.zig").Stack;

pub fn determineSize(tps: []const u8) ?u8 {
    var count: u8 = 1;
    for (tps) |char| {
        if (char == '/') count += 1;
    }
    if (count < game.min_n) return null;
    if (count > game.max_n) return null;
    return count;
}

pub fn parse(comptime n: u8, tps: []const u8) !Game(n) {
    std.debug.assert(n >= game.min_n);
    std.debug.assert(n <= game.max_n);

    var split_by_spaces = splitScalar(u8, tps, ' ');
    const board = split_by_spaces.next().?;
    const player_number = try parseUnsigned(u4, split_by_spaces.next() orelse "1", 10);
    const move_number = try parseUnsigned(u32, split_by_spaces.next() orelse "1", 10);

    const player: Color = switch (player_number) {
        1 => .White,
        2 => .Black,
        else => return error.InvalidPlayerNumber,
    };
    const opening = move_number < 1;

    var rows = splitScalar(u8, board, '/');
    var stacks: [n * n]Stack(n) = @splat(Stack(n).init());
    var index: usize = 0;
    var bit: BitBoard(n) = 1;
    var noble: BitBoard(n) = 0;
    var caps: BitBoard(n) = 0;
    while (rows.next()) |row| {
        const before_row = index;
        var items = splitScalar(u8, row, ',');
        while (items.next()) |item| {
            if (item.len == 0) {
                return error.TwoCommasAfterEachOther;
            }
            // empty squares
            if (item[0] == 'x') {
                const amount = if (item.len == 1) 1 else try parseUnsigned(u4, item[1..], 10);
                index += amount;
                bit <<= amount;
                continue;
            }
            // top piece
            const last = item[item.len - 1];
            var indicator = false;
            if (last == 'S') {
                noble |= bit;
                indicator = true;
            } else if (last == 'C') {
                noble |= bit;
                caps |= bit;
                indicator = true;
            }
            // stack
            const stack_numbers = if (indicator) item[0 .. item.len - 1] else item;
            const stack = &stacks[index];
            for (stack_numbers) |number| {
                const color: Color = switch (number) {
                    '1' => .White,
                    '2' => .Black,
                    else => return error.InvalidColorInStack,
                };
                stack.add_one(color);
            }
            index += 1;
            bit <<= 1;
        }
        if (index != before_row + n) {
            return error.WrongNumberOfItemsInRow;
        }
    }

    // TODO: Any other preprocessing?

    return .{
        .stacks = stacks,
        .noble = noble,
        .caps = caps,
        .player = player,
        .opening = opening,
    };
}
