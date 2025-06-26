const std = @import("std");
const stdout = std.io.getStdIn().writer();
const stderr = std.io.getStdErr().writer();

const clap = @import("clap");

const Game = @import("game.zig").Game;
const tps = @import("tps.zig");

// for tests
comptime {
    _ = @import("stack.zig");
    _ = @import("color.zig");
}

fn perft(comptime n: u8, game: *Game(n), depth: u8) u64 {
    _ = game;
    _ = depth;
    return 0;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help        Display this help and exit.
        \\-t, --tps <str>   Optional starting position given as TPS.
        \\<u8>              Specify the depth to search.
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        try diag.report(stderr, err);
        return;
    };
    defer res.deinit();

    if (res.args.help != 0) {
        try stderr.print("=== Tak Perft ===\n", .{});
        return clap.help(stderr, clap.Help, &params, .{
            .description_on_new_line = false,
            .spacing_between_parameters = 0,
            .indent = 2,
            .description_indent = 0,
        });
    }
    const depth = res.positionals[0] orelse {
        return stderr.print("You must specify the depth (as a positional argument).\n", .{});
    };
    const tps_str = res.args.tps orelse "x6/x6/x6/x6/x6/x6 1 1";

    const n = tps.determineSize(tps_str) orelse {
        return stderr.print("Unable to determine size from TPS.", .{});
    };
    return switch (n) {
        3 => genericMain(3, tps_str, depth),
        4 => genericMain(4, tps_str, depth),
        5 => genericMain(5, tps_str, depth),
        6 => genericMain(6, tps_str, depth),
        7 => genericMain(7, tps_str, depth),
        8 => genericMain(8, tps_str, depth),
        else => unreachable,
    };
}

fn genericMain(comptime n: u8, tps_str: []const u8, depth: u8) !void {
    // try stderr.print("[size: {d}] {s}\n", .{ n, tps_str });
    var game = tps.parse(n, tps_str) catch |err| {
        return stderr.print("Unable to parse TPS \"{s}\" with error {}.\n", .{ tps_str, err });
    };
    // try stderr.print("{any}\n", .{game.stacks});
    const positions = perft(n, &game, depth);
    return stdout.print("{d}\n", .{positions});
}
