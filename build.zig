const std = @import("std");

pub fn build(b: *std.Build) void {
    // options
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const opts = .{ .target = target, .optimize = optimize };

    // modules
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // executable
    const exe = b.addExecutable(.{
        .name = "tak_perft",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    // dependencies
    const clap = b.dependency("clap", opts).module("clap");
    exe.root_module.addImport("clap", clap);
    const zbench = b.dependency("zbench", opts).module("zbench");
    exe.root_module.addImport("zbench", zbench);

    // run cmd
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run perft");
    run_step.dependOn(&run_cmd.step);

    // test command
    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
