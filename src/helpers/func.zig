const std = @import("std");
const helpers = @import("helpers.zig");
const screen = @import("../screen/screen.zig");
const a_state = @import("../screen/app_state.zig");
const rays = @import("../math/ray.zig");
const Camera = rays.Camera;
const Ray = rays.Ray;
const intersect = @import("../math/intersect.zig");
const Hit = intersect.Hit;
const AppState = a_state.AppState;
const vec = @import("../math/vec.zig");
const UnitVec3 = vec.UnitVec3;
const Vec3 = vec.Vec3;
const tracy = @import("tracy");
const Zone = tracy.Zone;

const consts = @import("../helpers/const.zig");

pub fn create_ppm(app_state: *const AppState) !void {
    const width = app_state.*.width;
    const height = app_state.*.height;
    std.debug.assert(height > 0 and width > 0);
    const width_f64: f64 = @as(f64, @floatFromInt(width));
    const height_f64: f64 = @as(f64, @floatFromInt(height));
    const height_usize: usize = @intCast(height);
    const width_usize: usize = @intCast(width);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var pixels = try allocator.alloc([3]u8, width_usize * height_usize);

    const aspect_ratio: f64 = width_f64 / height_f64;

    for (0..height_usize) |y| {
        for (0..width_usize) |x| {
            const xf = @as(f64, @floatFromInt(x));
            const yf = @as(f64, @floatFromInt(y));

            const u = xf / (width_f64 - 1.0);
            const v = 1.0 - (yf / (height_f64 - 1.0));

            const x_ndc: f64 = (2.0 * u - 1.0) * aspect_ratio;
            const y_ndc: f64 = 2.0 * v - 1.0;

            const color = screen.ColorRGBf{
                .r = (x_ndc + aspect_ratio) / (2 * aspect_ratio),
                .g = (y_ndc + 1) / 2.0,
                .b = 0.0,
            };

            pixels[y * width_usize + x] = screen.colorToPixel(color);
        }
    }

    var buffer: std.ArrayList(u8) = .{};
    defer buffer.deinit(allocator);
    try helpers.encode_ppm(allocator, &buffer, pixels, height_usize, width_usize);
    try helpers.writeFileAtomic("output/images", "basic_image.ppm", buffer.items);
}

pub fn show_scene(
    scene: anytype,
    camera: Camera,
    use_color: bool,
    app_state: *const AppState,
) !void {
    const width = app_state.*.width;
    const height = app_state.*.height;
    std.debug.assert(height > 0 and width > 0);
    const height_usize: usize = @intCast(height);
    const width_usize: usize = @intCast(width);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var pixels = try allocator.alloc([3]u8, width_usize * height_usize);

    for (0..height_usize) |y| {
        for (0..width_usize) |x| {
            const ray: Ray = camera.get_ray(x, y);
            var closest_hit: ?Hit = null;
            const t_min: f64 = consts.epsilon;
            var t_max: f64 = std.math.floatMax(f64);

            inline for (scene) |object| {
                const hit: ?Hit = object.intersect(ray, t_min, t_max);
                if (hit) |h| {
                    if (closest_hit == null or h.t < t_max) {
                        t_max = h.t;
                        closest_hit = h;
                    }
                }
            }
            var color: screen.ColorRGBf = undefined;
            if (closest_hit) |h| {
                if (use_color) {
                    color = screen.ColorRGBf{
                        .r = h.material.color.r,
                        .g = h.material.color.g,
                        .b = h.material.color.b,
                    };
                }
            } else {
                color = screen.ColorRGBf{
                    .r = 0.0,
                    .g = 0.0,
                    .b = 1.0,
                };
            }

            pixels[y * width_usize + x] = screen.colorToPixel(color);
        }
    }

    var buffer: std.ArrayList(u8) = .{};
    defer buffer.deinit(allocator);
    try helpers.encode_ppm(allocator, &buffer, pixels, height_usize, width_usize);
    try helpers.writeFileAtomic("output/images", "show_scene.ppm", buffer.items);
}

pub fn lambertian_shading(
    scene: anytype,
    camera: Camera,
    app_state: *const AppState,
) !void {
    const width = app_state.*.width;
    const height = app_state.*.height;
    std.debug.assert(height > 0 and width > 0);
    const height_usize: usize = @intCast(height);
    const width_usize: usize = @intCast(width);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var pixels = try allocator.alloc([3]u8, width_usize * height_usize);

    const light_direction: UnitVec3 = UnitVec3.init(0, -1, 0);
    const direction_to_light: UnitVec3 = light_direction.flip();

    for (0..height_usize) |y| {
        for (0..width_usize) |x| {
            const ray: Ray = camera.get_ray(x, y);
            var closest_hit: ?Hit = null;
            const t_min: f64 = consts.epsilon;
            var t_max: f64 = std.math.floatMax(f64);

            inline for (scene) |object| {
                const hit: ?Hit = object.intersect(ray, t_min, t_max);
                if (hit) |h| {
                    if (closest_hit == null or h.t < t_max) {
                        t_max = h.t;
                        closest_hit = h;
                    }
                }
            }
            var color: screen.ColorRGBf = undefined;
            if (closest_hit) |h| {
                const light_factor: f64 = helpers.clamp01(h.normal.dot(direction_to_light));
                color = screen.ColorRGBf{
                    .r = h.material.color.r * light_factor,
                    .g = h.material.color.g * light_factor,
                    .b = h.material.color.b * light_factor,
                };
            } else {
                color = screen.ColorRGBf{
                    .r = 0.0,
                    .g = 0.0,
                    .b = 0.0,
                };
            }

            pixels[y * width_usize + x] = screen.colorToPixel(color);
        }
    }

    var buffer: std.ArrayList(u8) = .{};
    defer buffer.deinit(allocator);
    try helpers.encode_ppm(allocator, &buffer, pixels, height_usize, width_usize);
    try helpers.writeFileAtomic("output/images", "lambertian_shading.ppm", buffer.items);
}

pub fn shadows(
    scene: anytype,
    camera: Camera,
    app_state: *const AppState,
) !void {
    const width = app_state.*.width;
    const height = app_state.*.height;
    std.debug.assert(height > 0 and width > 0);
    const height_usize: usize = @intCast(height);
    const width_usize: usize = @intCast(width);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var pixels = try allocator.alloc([3]u8, width_usize * height_usize);

    const light_direction: UnitVec3 = UnitVec3.init(0, -1, 0);
    const direction_to_light: UnitVec3 = light_direction.flip();

    for (0..height_usize) |y| {
        for (0..width_usize) |x| {
            const ray: Ray = camera.get_ray(x, y);
            var closest_hit: ?Hit = null;
            const t_min: f64 = consts.epsilon;
            var t_max: f64 = std.math.floatMax(f64);

            inline for (scene) |object| {
                const hit: ?Hit = object.intersect(ray, t_min, t_max);
                if (hit) |h| {
                    if (closest_hit == null or h.t < t_max) {
                        t_max = h.t;
                        closest_hit = h;
                    }
                }
            }
            var color: screen.ColorRGBf = undefined;
            if (closest_hit) |h| {
                const light_factor: f64 = helpers.clamp01(h.normal.dot(direction_to_light));
                var shadow: f64 = undefined;
                if (light_factor > 0) {
                    const shadow_ray: Ray = Ray.init(h.point, direction_to_light);
                    var closest_shadow_hit: ?Hit = null;
                    inline for (scene) |object| {
                        const shadow_hit: ?Hit = object.intersect(shadow_ray, consts.epsilon, std.math.floatMax(f64));
                        if (shadow_hit) |sh| {
                            if (closest_shadow_hit == null or sh.t < t_max) {
                                t_max = sh.t;
                                closest_shadow_hit = sh;
                            }
                        }
                    }
                    if (closest_shadow_hit == null) shadow = 1.0 else shadow = 0.0;
                } else shadow = 0.0;
                color = screen.ColorRGBf{
                    .r = h.material.color.r * light_factor * shadow,
                    .g = h.material.color.g * light_factor * shadow,
                    .b = h.material.color.b * light_factor * shadow,
                };
            } else {
                color = screen.ColorRGBf{
                    .r = 0.0,
                    .g = 0.0,
                    .b = 0.0,
                };
            }

            pixels[y * width_usize + x] = screen.colorToPixel(color);
        }
    }

    var buffer: std.ArrayList(u8) = .{};
    defer buffer.deinit(allocator);
    try helpers.encode_ppm(allocator, &buffer, pixels, height_usize, width_usize);
    try helpers.writeFileAtomic("output/images", "shadows.ppm", buffer.items);
}

pub fn depth_tracing(
    scene: anytype,
    camera: Camera,
    app_state: *const AppState,
) !void {
    const frame_zone = Zone.begin(.{
        .name = "frame::depth_tracing",
        .src = @src(),
        .color = .tomato,
    });
    defer frame_zone.end();
    const width = app_state.*.width;
    const height = app_state.*.height;
    std.debug.assert(height > 0 and width > 0);
    const height_usize: usize = @intCast(height);
    const width_usize: usize = @intCast(width);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Wrap the arena allocator with Tracy
    var tracy_allocator: tracy.Allocator = .{
        .parent = arena.allocator(),
    };

    const allocator = tracy_allocator.allocator();
    var pixels = try allocator.alloc([3]u8, width_usize * height_usize);
    const depth: u8 = 25;

    for (0..height_usize) |y| {
        const row_zone = Zone.begin(.{
            .name = "row_loop",
            .src = @src(),
            .color = .orange,
        });
        defer row_zone.end();
        for (0..width_usize) |x| {
            const ray: Ray = camera.get_ray(x, y);
            const color = ray_trace(scene, depth, ray);
            pixels[y * width_usize + x] = screen.colorToPixel(color);
        }
    }

    var buffer: std.ArrayList(u8) = .{};
    defer buffer.deinit(allocator);
    const filename = try std.fmt.allocPrint(
        allocator,
        "depth_tracing{d}.ppm",
        .{depth},
    );
    try helpers.encode_ppm(allocator, &buffer, pixels, height_usize, width_usize);
    try helpers.writeFileAtomic("output/images", filename, buffer.items);
}

fn ray_trace(scene: anytype, depth: u8, ray: Ray) screen.ColorRGBf {
    const ray_zone = Zone.begin(.{
        .name = "ray_trace",
        .src = @src(),
        .color = .red,
    });
    defer ray_zone.end();
    if (depth <= 0) return screen.BLACK;

    var closest_hit: ?Hit = null;
    const t_min: f64 = consts.epsilon;
    var t_max: f64 = std.math.floatMax(f64);

    {
        const intersect_zone = Zone.begin(.{
            .name = "scene_intersection",
            .src = @src(),
            .color = .yellow,
        });
        defer intersect_zone.end();
        inline for (scene) |object| {
            const hit: ?Hit = object.intersect(ray, t_min, t_max);
            if (hit) |h| {
                if (closest_hit == null or h.t < t_max) {
                    t_max = h.t;
                    closest_hit = h;
                }
            }
        }
    }

    if (closest_hit) |h| {
        const shade_zone = Zone.begin(.{
            .name = "shading",
            .src = @src(),
            .color = .green,
        });
        defer shade_zone.end();
        const reflected_vector: Vec3 = ray.direction.asVec3().sub(h.normal.asVec3().scale(Vec3.dot(ray.direction.asVec3(), h.normal.asVec3()) * 2.0));
        const reflected_dir: UnitVec3 = UnitVec3.normalize(reflected_vector);
        const reflected_ray = Ray.init(h.point, reflected_dir);

        const light_direction: UnitVec3 = UnitVec3.init(0, -1, 0);
        const direction_to_light: UnitVec3 = light_direction.flip();
        const light_factor: f64 = helpers.clamp01(h.normal.dot(direction_to_light));

        var shadow: f64 = undefined;
        if (light_factor > 0) {
            const shadow_zone = Zone.begin(.{
                .name = "shadow_ray",
                .src = @src(),
                .color = .blue,
            });
            defer shadow_zone.end();
            const shadow_ray: Ray = Ray.init(h.point, direction_to_light);
            var closest_shadow_hit: ?Hit = null;
            inline for (scene) |object| {
                const shadow_hit: ?Hit = object.intersect(shadow_ray, consts.epsilon, std.math.floatMax(f64));
                if (shadow_hit) |sh| {
                    if (closest_shadow_hit == null or sh.t < t_max) {
                        t_max = sh.t;
                        closest_shadow_hit = sh;
                    }
                }
            }
            if (closest_shadow_hit == null) shadow = 1.0 else shadow = 0.0;
        } else shadow = 0.0;

        const local_lighting: f64 = helpers.clamp01(light_factor) * shadow;
        const color = screen.ColorRGBf{
            .r = h.material.color.r * local_lighting,
            .g = h.material.color.g * local_lighting,
            .b = h.material.color.b * local_lighting,
        };
        const recurse_zone = Zone.begin(.{
            .name = "reflection_recursion",
            .src = @src(),
            .color = .purple,
        });
        const ray_color = ray_trace(scene, depth - 1, reflected_ray);
        recurse_zone.end();
        return screen.colorReflected(color, ray_color, h.material.reflectivity);
    } else {
        return screen.BLACK;
    }
}
