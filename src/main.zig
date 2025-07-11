const std = @import("std");
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const clap = @import("clap");

const perft = @import("perft.zig");
const state = @import("state.zig");
const tps = @import("tps.zig");

comptime { // for tests
    _ = @import("bench.zig");
    _ = @import("bitboard.zig");
    _ = @import("color.zig");
    _ = @import("lut.zig");
    _ = @import("perft.zig");
    _ = @import("reserves.zig");
    _ = @import("stack.zig");
    _ = @import("state.zig");
    _ = @import("tps.zig");
}

const params = clap.parseParamsComptime(
    \\-h, --help        Display this message and exit.
    \\-t, --tps <str>   Optional position given as TPS.
    \\<u8>              Specify the depth to search.
);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        return diag.report(stderr, err);
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
        return stderr.print(
            \\Could not determine a valid size from the TPS.
            \\Only sizes between {d} and {d} are supported.
            \\
        , .{ state.min_n, state.max_n });
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

fn genericMain(n: comptime_int, tps_str: []const u8, depth: u8) !void {
    var game = tps.parse(n, tps_str) catch |err| {
        return stderr.print(
            \\Unable to parse TPS "{s}".
            \\Encountered {}.
            \\
        , .{ tps_str, err });
    };
    const positions = perft.countPositions(n, &game, depth);
    return stdout.print("{d}\n", .{positions});
}
