const std = @import("std");
const assert = std.debug.assert;
const c = @import("constants.zig");
const io = std.Options.debug_io;

/// Clamps a finite f64 into the range [0, 255] and truncates toward zero.
///
/// Preconditions:
/// - `x` must be finite (not NaN, not ±Inf).
///
/// Behavior:
/// - Otherwise truncates toward zero
///
/// Asserts if `x` is NaN or ±Inf.
///
pub fn clamp_f64_u8(x: f64) u8 {
    assert(std.math.isFinite(x));
    if (x < 0.0) return 0;
    if (x > 255.0) return 255;
    return @intFromFloat(x);
}

pub fn clamp01(x: f64) f64 {
    return if (x < 0.0) 0.0 else if (x > 1.0) 1.0 else x;
}

pub fn floatToU8(x: f64) u8 {
    return @intFromFloat(clamp01(x) * 255.0);
}

pub fn encode_ppm(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8), pixels: []const [3]u8, height: usize, width: usize) !void {
    std.debug.assert(pixels.len == width * height);

    try buffer.writer(allocator).print("P6\n{} {}\n255\n", .{ width, height });
    for (pixels) |px| {
        try buffer.appendSlice(allocator, &px);
    }
}

pub fn writeFileAtomic(
    dir_path: []const u8,
    final_name: []const u8,
    data: []const u8,
) !void {
    const cwd = std.fs.cwd();
    try cwd.makePath(dir_path);

    var dir = try cwd.openDir(dir_path, .{});
    defer dir.close();

    // Temporary filename (same directory!)
    const tmp_name = try std.fmt.allocPrint(
        std.heap.page_allocator,
        ".{s}.tmp",
        .{final_name},
    );
    defer std.heap.page_allocator.free(tmp_name);

    // Create temp file (truncate if exists)
    var file = try dir.createFile(tmp_name, .{
        .read = false,
        .truncate = true,
    });
    defer file.close();

    try file.writeAll(data);
    // Ensure data hits disk
    try file.sync();
    // Atomically replace final file
    try dir.rename(tmp_name, final_name);
}
