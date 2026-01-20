const std = @import("std");
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const UnitVec3 = vec.UnitVec3;

pub const Ray = struct {
    origin: Vec3,
    direction: UnitVec3,

    pub fn init(origin: Vec3, direction: UnitVec3) Ray {
        return Ray{
            .origin = origin,
            .direction = direction,
        };
    }
};

pub const Camera = struct {
    lookfrom: Vec3,
    lookat: Vec3,
    vfov_degrees: f64,
    pixel_width: u32,
    pixel_height: u32,
    aspect_ratio: f64,
    w: UnitVec3,
    u: UnitVec3,
    v: UnitVec3,
    focal_length: f64,
    viewport_height: f64,
    viewport_width: f64,
    image_plane_center: Vec3,
    image_plane_upper_left: Vec3,
    h_step: Vec3,
    v_step: Vec3,

    pub fn init(lookfrom: Vec3, lookat: Vec3, vup: UnitVec3, vfov_degrees: f64, pixel_width_i32: i32, pixel_height_i32: i32, focal_length: f64) Camera {
        std.debug.assert(pixel_width_i32 > 0 and pixel_height_i32 > 0);
        const pixel_width_u32: u32 = @intCast(pixel_width_i32);
        const pixel_height_u32: u32 = @intCast(pixel_height_i32);

        const w: UnitVec3 = UnitVec3.normalize(lookfrom.sub(lookat));
        const u: UnitVec3 = UnitVec3.normalize(UnitVec3.cross(vup, w));
        const v: UnitVec3 = UnitVec3.normalize(UnitVec3.cross(w, u));
        const aspect_ratio: f64 = @as(f64, @floatFromInt(pixel_width_u32)) / @as(f64, @floatFromInt(pixel_height_u32));

        const viewport_height = 2.0 * focal_length * @tan(std.math.degreesToRadians(vfov_degrees / 2.0));
        const viewport_width = viewport_height * aspect_ratio;
        const image_plane_center: Vec3 = lookfrom.add(w.scale(focal_length * -1));
        const image_plane_upper_left: Vec3 = image_plane_center.sub(u.scale(viewport_width * 0.5).sub(v.scale(viewport_height * 0.5)));

        return Camera{
            .lookfrom = lookfrom,
            .lookat = lookat,
            .vfov_degrees = vfov_degrees,
            .pixel_width = pixel_width_u32,
            .pixel_height = pixel_height_u32,
            .focal_length = focal_length,
            .aspect_ratio = aspect_ratio,
            .w = w,
            .u = u,
            .v = v,
            .viewport_height = viewport_height,
            .viewport_width = viewport_width,
            .image_plane_center = image_plane_center,
            .image_plane_upper_left = image_plane_upper_left,
            .h_step = u.scale(viewport_width / @as(f64, @floatFromInt(pixel_width_u32))),
            .v_step = v.scale(viewport_height / @as(f64, @floatFromInt(pixel_height_u32)) * -1.0),
        };
    }

    pub fn get_ray(self: Camera, i: usize, j: usize) Ray {
        const fi = @as(f64, @floatFromInt(i));
        const fj = @as(f64, @floatFromInt(j));
        const direction: UnitVec3 = UnitVec3.normalize(self.image_plane_upper_left
            .add(self.h_step.scale(fi + 0.5).add(self.v_step.scale(fj + 0.5)))
            .sub(self.lookfrom));
        return Ray.init(self.lookfrom, direction);
    }
};
