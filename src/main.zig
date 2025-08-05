const std = @import("std");

const TAILWIND_VERSION = "v4.1.11";
const GITHUB_BASE_URL = "https://github.com/tailwindlabs/tailwindcss/releases/download/";

fn getPlatformExecutableName() []const u8 {
    const target = @import("builtin").target;

    const os_name = switch (target.os.tag) {
        .linux => "linux",
        .macos => "macos",
        .windows => "windows",
        else => @panic("Unsupported operating system"),
    };

    const arch_name = switch (target.cpu.arch) {
        .x86_64 => "x64",
        .aarch64 => "arm64",
        else => @panic("Unsupported architecture"),
    };

    const extension = switch (target.os.tag) {
        .windows => ".exe",
        else => "",
    };

    // For Linux, we'll use the musl variants for better compatibility
    const musl_suffix = switch (target.os.tag) {
        .linux => "-musl",
        else => "",
    };

    return std.fmt.comptimePrint("tailwindcss-{s}-{s}{s}{s}", .{ os_name, arch_name, musl_suffix, extension });
}

fn buildDownloadUri(allocator: std.mem.Allocator) !std.Uri {
    const executable_name = getPlatformExecutableName();
    const path = try std.fmt.allocPrint(allocator, "/tailwindlabs/tailwindcss/releases/download/{s}/{s}", .{ TAILWIND_VERSION, executable_name });

    return std.Uri{
        .scheme = "https",
        .host = .{ .raw = "github.com" },
        .path = .{ .raw = path },
    };
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    std.debug.assert(args.skip());
    const executable_path = args.next() orelse fatal("Missing output file argument.", .{});

    const output_file = try std.fs.cwd().createFile(executable_path, .{});
    defer output_file.close();

    var output_file_writer_buffer: [1024]u8 = undefined;
    var output_file_writer = output_file.writer(&output_file_writer_buffer);
    const writer = &output_file_writer.interface;

    // Build the download URI dynamically based on target platform
    const download_uri = try buildDownloadUri(allocator);
    defer allocator.free(download_uri.path.raw);

    std.debug.print("Downloading Tailwind CSS executable for platform: {s}...\n", .{getPlatformExecutableName()});

    var http_client: std.http.Client = .{ .allocator = allocator };
    try http_client.initDefaultProxies(allocator);
    defer http_client.deinit();

    var request = try http_client.request(.GET, download_uri, .{});
    defer request.deinit();

    try request.sendBodiless();
    var redirect_buffer: [1024]u8 = undefined;
    var response = try request.receiveHead(&redirect_buffer);

    var response_buffer: [4 * 1024]u8 = undefined;
    const body_reader = response.reader(&response_buffer);
    _ = try body_reader.streamRemaining(writer);

    try writer.flush();
    try output_file.chmod(0x770);

    return std.process.cleanExit();
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
