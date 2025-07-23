const std = @import("std");

const DOWNLOAD_URI: std.Uri = .{
    .scheme = "https",
    .host = .{ .raw = "github.com" },
    .path = .{ .raw = "/tailwindlabs/tailwindcss/releases/download/v4.1.11/tailwindcss-macos-x64" },
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
    const output_file_writer = output_file.writer();

    var http_client: std.http.Client = .{ .allocator = allocator };
    try http_client.initDefaultProxies(allocator);
    defer http_client.deinit();

    var server_header_buffer: [1024 * 1024]u8 = undefined;
    var request = try http_client.open(.GET, DOWNLOAD_URI, .{ .server_header_buffer = &server_header_buffer });
    defer request.deinit();

    request.send() catch fatal("failed to fetch tailwindcss executable", .{});
    request.wait() catch fatal("failed to fetch tailwindcss executable", .{});

    var buffer: [4 * 1024 * 1024]u8 = undefined;
    while (true) {
        const bytes_read = request.read(&buffer) catch fatal("failed to fetch tailwindcss executable", .{});
        if (bytes_read == 0) {
            break;
        }

        try output_file_writer.writeAll(buffer[0..bytes_read]);
    }

    try output_file.chmod(0x770);

    return std.process.cleanExit();
}

fn fatal(comptime format: []const u8, args: anytype) noreturn {
    std.debug.print(format, args);
    std.process.exit(1);
}
