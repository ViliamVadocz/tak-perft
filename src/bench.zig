const std = @import("std");
const stderr = std.io.getStdErr().writer();

const zbench = @import("zbench");

const tps = @import("tps.zig");
const perft = @import("perft.zig");
const State = @import("state.zig").State;
const table = @import("table.zig");

fn benchPerft(n: comptime_int, depth: comptime_int, comptime tps_str: []const u8, tt: *table.Table) zbench.BenchFunc {
    @setEvalBranchQuota(2_000);
    const state: State(n) = comptime tps.parse(n, tps_str) catch unreachable;
    const static = struct {
        var t: *table.Table = undefined;
    };
    static.t = tt;
    return struct {
        fn bench(_: std.mem.Allocator) void {
            var s = state;
            _ = perft.countPositions(n, &s, depth, static.t);
        }
    }.bench;
}

fn zeroOutTT(tt: *table.Table) *const fn () void {
    const static = struct {
        var t: *table.Table = undefined;
    };
    static.t = tt;
    return struct {
        fn zero() void {
            @memset(static.t, table.init_bucket);
        }
    }.zero;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}).init;
    defer _ = gpa.deinit(); // TODO: Maybe check for leaks?
    const allocator = gpa.allocator();

    const tt = try allocator.create(table.Table);
    // NOTE: Will be zeroed out before every benchmark.
    defer allocator.destroy(tt);

    var bench = zbench.Benchmark.init(allocator, .{
        .time_budget_ns = 10e9,
        .max_iterations = 100,
        .hooks = .{ .before_each = zeroOutTT(tt) },
    });
    defer bench.deinit();

    const Position = struct {
        name: []const u8,
        n: comptime_int,
        max_depth: comptime_int,
        tps_str: []const u8,
    };
    const benches = [_]Position{
        .{ .name = "3x3 opening", .n = 3, .max_depth = 9, .tps_str = "x3/x3/x3 1 1" },
        .{ .name = "4x4 opening", .n = 4, .max_depth = 7, .tps_str = "x4/x4/x4/x4 1 1" },
        .{ .name = "5x5 opening", .n = 5, .max_depth = 6, .tps_str = "x5/x5/x5/x5/x5 1 1" },
        .{ .name = "6x6 opening", .n = 6, .max_depth = 5, .tps_str = "x6/x6/x6/x6/x6/x6 1 1" },
        .{ .name = "7x7 opening", .n = 7, .max_depth = 5, .tps_str = "x7/x7/x7/x7/x7/x7/x7 1 1" },
        .{ .name = "8x8 opening", .n = 8, .max_depth = 5, .tps_str = "x8/x8/x8/x8/x8/x8/x8/x8 1 1" },
        .{ .name = "3x3 stacks", .n = 3, .max_depth = 7, .tps_str = "111,221,x/221,221,x/x3 1 100" },
        .{ .name = "4x4 stacks", .n = 4, .max_depth = 6, .tps_str = "1111,2221,x2/2221,2221,x2/x4/x4 1 100" },
        .{ .name = "5x5 stacks", .n = 5, .max_depth = 5, .tps_str = "11111,22221,x3/22221,22221,x3/x5/x5/x5 1 100" },
        .{ .name = "6x6 stacks", .n = 6, .max_depth = 4, .tps_str = "111111,111111,222221,x3/111111,111111,222221,x3/222221,222221,222221,x3/x6/x6/x6 1 100" },
        .{ .name = "7x7 stacks", .n = 7, .max_depth = 4, .tps_str = "1111111,1111111,2222221,x4/1111111,1111111,2222221,x4/2222221,2222221,2222221,x4/x7/x7/x7/x7 1 100" },
        .{ .name = "8x8 stacks", .n = 8, .max_depth = 4, .tps_str = "11111111,11111111,22222221,x5/11111111,11111111,22222221,x5/22222221,22222221,22222221,x5/x8/x8/x8/x8/x8 1 100" },
        .{ .name = "3x3 walls", .n = 3, .max_depth = 9, .tps_str = "11S,1S,x/1S,x,2S/x,2S,22S 2 50" },
        .{ .name = "4x4 walls", .n = 4, .max_depth = 7, .tps_str = "11S,1S,1S,x/1S,1S,x,2S/1S,x,2S,2S/x,2S,2S,22S 2 50" },
        .{ .name = "5x5 walls", .n = 5, .max_depth = 6, .tps_str = "11S,1S,1S,1S,x/1S,1S,1S,x,2S/1S,1S,x,2S,2S/1S,x,2S,2S,2S/x,2S,2S,2S,22S 2 50" },
        .{ .name = "6x6 walls", .n = 6, .max_depth = 5, .tps_str = "11S,1S,1S,1S,1S,x/1S,1S,1S,1S,x,2S/1S,1S,1S,x,2S,2S/1S,1S,x,2S,2S,2S/1S,x,2S,2S,2S,2S/x,2S,2S,2S,2S,22S 2 50" },
        .{ .name = "7x7 walls", .n = 7, .max_depth = 5, .tps_str = "11S,1S,1S,1S,1S,1S,x/1S,1S,1S,1S,1S,x,2S/1S,1S,1S,1S,x,2S,2S/1S,1S,1S,x,2S,2S,2S/1S,1S,x,2S,2S,2S,2S/1S,x,2S,2S,2S,2S,2S/x,2S,2S,2S,2S,2S,22S 2 50" },
        .{ .name = "8x8 walls", .n = 8, .max_depth = 5, .tps_str = "11S,1S,1S,1S,1S,1S,1S,x/1S,1S,1S,1S,1S,1S,x,2S/1S,1S,1S,1S,1S,x,2S,2S/1S,1S,1S,1S,x,2S,2S,2S/1S,1S,1S,x,2S,2S,2S,2S/1S,1S,x,2S,2S,2S,2S,2S/1S,x,2S,2S,2S,2S,2S,2S/x,2S,2S,2S,2S,2S,2S,22S 2 50" },
        .{ .name = "5x5 smashes", .n = 5, .max_depth = 6, .tps_str = "x,2S,2S,2S,x/2S,2S,2S,22S,2S/2S,x,11111C,2C,2S/2S,2S,2S,22S,2S/x,2S,2S,2S,x 1 70" },
        .{ .name = "6x6 smashes", .n = 6, .max_depth = 5, .tps_str = "x,2S,2S,2S,2S,x/2S,2S,2S,2S,22S,2S/2S,x,111111C,x,2C,2S/2S,2S,2S,2S,22S,2S/x,2S,2S,2S,2S,2S/x2,2S,2S,2S,x 1 70" },
        .{ .name = "7x7 smashes", .n = 7, .max_depth = 4, .tps_str = "x2,2S,2S,2S,2S,x/x,2S,2S,2S,2S,2S,2S/2S,2S,2S,x,2S,22S,2S/2S,x2,1111111C,x,2C,2S/2S,2S,2S,2S,2S,22S,2S/x,2S,2S,2S,2S,2S,2S/x2,2S,2S,2S,2S,x 1 70" },
        .{ .name = "8x8 smashes", .n = 8, .max_depth = 4, .tps_str = "x2,2S,2S,2S,2S,2S,x/x,2S,2S,2S,2S,2S,2S,2S/2S,2S,2S,x,2S,2S,22S,2S/2S,x2,11111111C,x2,2C,2S/2S,2S,2S,x,2S,2S,22S,2S/2S,2S,2S,x,2S,2S,2S,2S/x,2S,2S,x,2S,2S,2S,2S/x2,2S,2S,2S,2S,2S,x 1 70" },
    };

    inline for (benches) |position| {
        std.debug.assert(position.max_depth >= 1);
        inline for (1..(position.max_depth + 1)) |depth| {
            const name = position.name ++ ", depth " ++ [1]u8{'0' + depth};
            try bench.add(name, benchPerft(position.n, depth, position.tps_str, tt), .{});
        }
    }

    try bench.run(stderr);
}

fn bench3x3StacksDepth5(_: std.mem.Allocator) void {
    const n = 3;
    const depth = 5;
    var state: State(n) = comptime tps.parse(n, "111,221,x/221,221,x/x2,111 1 10") catch unreachable;
    _ = perft.countPositions(n, &state, depth);
}

fn bench4x4StacksDepth5(_: std.mem.Allocator) void {
    const n = 4;
    const depth = 5;
    var state: State(n) = comptime tps.parse(n, "1111,1111,x2/1111,2221,x2/x2,2221,x/x4 1 10") catch unreachable;
    _ = perft.countPositions(n, &state, depth);
}

fn bench5x5StacksDepth4(_: std.mem.Allocator) void {
    const n = 5;
    const depth = 4;
    var state: State(n) = comptime tps.parse(n, "11111,11111,x3/11111,11111,x3/x2,22221C,x2/x5/x5 1 10") catch unreachable;
    _ = perft.countPositions(n, &state, depth);
}

fn bench6x6StacksDepth4(_: std.mem.Allocator) void {
    const n = 6;
    const depth = 4;
    var state: State(n) = comptime tps.parse(n, "111111,111111,222221,x3/111111,111111,222221,x3/222221,222221,222221,x3/x3,22221C,x2/x6/x6 1 10") catch unreachable;
    _ = perft.countPositions(n, &state, depth);
}

fn bench7x7StacksDepth3(_: std.mem.Allocator) void {
    @setEvalBranchQuota(2_000);
    const n = 7;
    const depth = 3;
    var state: State(n) = comptime tps.parse(n, "1111111,1111111,2222221,x4/1111111,1111111,2222221,x4/2222221,2222221,2222221,x4/x3,1111111C,x3/x7/x5,2222222C,x/x7 1 1") catch unreachable;
    _ = perft.countPositions(n, &state, depth);
}

fn bench8x8StacksDepth3(_: std.mem.Allocator) void {
    @setEvalBranchQuota(2_000);
    const n = 8;
    const depth = 3;
    var state: State(n) = comptime tps.parse(n, "11111111,11111111,22222221,x5/11111111,11111111,22222221,x5/22222221,22222221,22222221,x5/x3,11111111C,x4/x8/x5,22222222C,x2/x8/x8 1 1") catch unreachable;
    _ = perft.countPositions(n, &state, depth);
}

// TODO: Add more benchmarks for different situations

// fn bench3x3FilledWithWalls(_: std.mem.Allocator) void {
//     const n = 3;
//     const depth = 10;
//     var state: State(n) = comptime tps.parse(3, "21S,2S,2S/1S,x,1S/1S,2S,12S 1 7");
// }
