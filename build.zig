const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const opts = .{ .target = target, .optimize = optimize };
    const install_step = b.getInstallStep();

    // main module
    const main_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const clap = b.dependency("clap", opts).module("clap");
    main_module.addImport("clap", clap);

    // create Zobirst LUT
    const zobrist = b.addExecutable(.{
        .name = "zobrist",
        .root_source_file = b.path("src/zobrist.zig"),
        .target = b.graph.host,
        .optimize = .Debug,
    });
    const zobrist_step = b.addRunArtifact(zobrist);
    const output = zobrist_step.addOutputFileArg("zobrist.bin");
    main_module.addAnonymousImport("zobrist_stack_change", .{
        .root_source_file = output,
    });

    // tak_perft binary
    const tak_perft = b.addExecutable(.{
        .name = "tak-perft",
        .root_module = main_module,
    });
    b.installArtifact(tak_perft);

    // run
    const run_tak_perft = b.addRunArtifact(tak_perft);
    run_tak_perft.step.dependOn(install_step);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_tak_perft.step);

    // test
    const test_filter = b.option([]const u8, "test-filter", "Only run tests that match this filter");
    const unit_tests = b.addTest(.{
        .root_module = main_module,
        .filter = test_filter,
    });
    // b.installArtifact(unit_tests);
    const run_unit_tests = b.addRunArtifact(unit_tests);
    run_unit_tests.step.dependOn(install_step);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // bench
    const benchmark = b.addExecutable(.{
        .name = "benchmark",
        .root_source_file = b.path("src/bench.zig"),
        .target = b.graph.host,
        .optimize = .ReleaseFast,
    });
    // zbench dependency
    const zbench = b.dependency("zbench", .{ .target = b.graph.host, .optimize = .ReleaseFast }).module("zbench");
    benchmark.root_module.addImport("zbench", zbench);
    // bench step
    const run_benchmarks = b.addRunArtifact(benchmark);
    run_benchmarks.step.dependOn(install_step);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_benchmarks.step);
}
