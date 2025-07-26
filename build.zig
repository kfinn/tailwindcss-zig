const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "tailwindcss_zig",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

pub const TailwindCssOptions = struct {
    input: std.Build.LazyPath,
    output: []const u8 = "tailwind.css",
    minify: bool = true,
};

const TailwindcssStep = struct {
    run_step: *std.Build.Step.Run,
    output_file: std.Build.LazyPath,
};

pub fn addTailwindcssStep(b: *std.Build, options: TailwindCssOptions) TailwindcssStep {
    const tailwindcss_zig_dep = b.dependency("tailwindcss", .{ .target = b.graph.host });
    const tailwindcss_zig_exe = tailwindcss_zig_dep.artifact("tailwindcss_zig");

    const tailwindcss_zig_exe_step = b.addRunArtifact(tailwindcss_zig_exe);
    const tailwindcss_zig_exe_step_output = tailwindcss_zig_exe_step.addOutputFileArg("tailwindcss");

    const tailwindcss_run_cmd = std.Build.Step.Run.create(b, "Run tailwindcss");
    tailwindcss_run_cmd.has_side_effects = true;
    tailwindcss_run_cmd.addFileArg(tailwindcss_zig_exe_step_output);
    if (options.minify) {
        tailwindcss_run_cmd.addArg("-m");
    }
    tailwindcss_run_cmd.addArg("-i");
    tailwindcss_run_cmd.addFileArg(options.input);
    tailwindcss_run_cmd.addArg("-o");
    const tailwindcss_run_output = tailwindcss_run_cmd.addOutputFileArg(options.output);

    const run_cmd = std.Build.Step.Run.create(b, "Run tailwindcss");
    run_cmd.addFileArg(tailwindcss_zig_exe_step_output);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("tailwindcss", "Run the tailwindcss CLI");
    run_step.dependOn(&run_cmd.step);

    return .{
        .run_step = tailwindcss_run_cmd,
        .output_file = tailwindcss_run_output,
    };
}
