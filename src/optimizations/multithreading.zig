const std = @import("std");

pub const Tile = struct {
    x0: usize,
    y0: usize,
    x1: usize,
    y1: usize,
};

/// caller must free memory
///
/// 9.1 / 10 code review
pub inline fn allocTiles(allocator: std.mem.Allocator, width: usize, height: usize, h_tile: usize, v_tile: usize) ![]Tile {
    std.debug.assert(h_tile > 0 and v_tile > 0);
    const horizontal_tiles = (width + h_tile - 1) / h_tile;
    const vertical_tiles = (height + v_tile - 1) / v_tile;
    std.debug.assert(horizontal_tiles * vertical_tiles <= std.math.maxInt(usize));

    var tiles = try allocator.alloc(Tile, horizontal_tiles * vertical_tiles);

    for (0..vertical_tiles) |y| {
        for (0..horizontal_tiles) |x| {
            const x0 = x * h_tile;
            const y0 = y * v_tile;
            tiles[y * horizontal_tiles + x] = Tile{ .x0 = x0, .y0 = y0, .x1 = @min(x0 + h_tile, width), .y1 = @min(y0 + v_tile, height) };
        }
    }
    return tiles;
}

pub const WorkerCtx = struct {
    id: usize,
    worker_count: usize,
};
