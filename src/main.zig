const std = @import("std");
const builtin = @import("builtin");

const DOWNLOAD_URI: std.Uri = .{
    .scheme = "https",
    .host = .{ .raw = "github.com" },
    .path = .{
        .raw = switch (builtin.os.tag) {
            .linux => "/tailwindlabs/tailwindcss/releases/download/v4.1.14/tailwindcss-linux-x64",
            .macos => "/tailwindlabs/tailwindcss/releases/download/v4.1.14/tailwindcss-macos-x64",
            else => unreachable,
        },
    },
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    std.debug.assert(args.skip());
    const executable_path = args.next() orelse fatal("Missing output file argument.", .{});

    const output_file = try std.fs.cwd().createFile(executable_path, .{});
    defer output_file.close();

    var output_file_writer_buffer: [1024]u8 = undefined;
    var output_file_writer = output_file.writer(&output_file_writer_buffer);
    const writer = &output_file_writer.interface;

    var http_client: std.http.Client = .{ .allocator = allocator };
    try http_client.initDefaultProxies(allocator);
    defer http_client.deinit();

    var request = try http_client.request(.GET, DOWNLOAD_URI, .{});
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
