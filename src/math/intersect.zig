const std = @import("std");
const consts = @import("../helpers/const.zig");

const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const UnitVec3 = vec.UnitVec3;

const ray_file = @import("ray.zig");
const Ray = ray_file.Ray;

const screen = @import("../screen/screen.zig");
const Material = screen.Material;

pub const Hit = struct {
    t: f64,
    point: Vec3,
    normal: UnitVec3,
    front_face: bool,
    material: Material,
};

pub fn intersect(entities: anytype, ray: Ray, t_min: f64, t_max: f64) ?Hit {
    var closest = t_max;
    var result: ?Hit = null;

    inline for (entities) |entity| {
        if (entity.intersect(ray, t_min, closest)) |hit| {
            closest = hit.t;
            result = hit;
        }
    }

    return result;
}

pub const Plane = struct {
    point: Vec3,
    normal: UnitVec3,
    material: Material,

    pub fn intersect(self: Plane, ray: Ray, t_min: f64, t_max: f64) ?Hit {
        const o: Vec3 = ray.origin;
        const d = ray.direction;
        const p = self.point;
        const n: UnitVec3 = self.normal;
        const dot: f64 = UnitVec3.dot(n, d);
        if (@abs(dot) < consts.epsilon) return null;
        const t: f64 = Vec3.dot(n.asVec3(), p.sub(o)) / UnitVec3.dot(n, d);
        if (t_min < t and t < t_max) {
            const point: Vec3 = o.add(d.scale(t));
            const front_face: bool = dot < 0;
            const normal: UnitVec3 = if (front_face) n else n.flip();
            return Hit{
                .t = t,
                .point = point,
                .normal = normal,
                .front_face = true,
                .material = self.material,
            };
        }
        return null;
    }
};

pub const Sphere = struct {
    center: Vec3,
    radius: f64,
    material: Material,

    pub fn intersect(self: Sphere, ray: Ray, t_min: f64, t_max: f64) ?Hit {
        const o = ray.origin;
        const center = self.center;
        const d = ray.direction;
        const r = self.radius;
        const dist = o.sub(center);

        const a: f64 = 1.0;
        const b: f64 = Vec3.dot(dist, d.asVec3()) * 2.0;
        const c: f64 = Vec3.dot(dist, dist) - r * r;
        const discriminant: f64 = b * b - 4.0 * a * c;

        if (discriminant < 0) return null;

        const root: f64 = std.math.sqrt(discriminant);
        var t: f64 = undefined;
        const t1: f64 = (-b - root) / (2.0 * a);
        const t2: f64 = (-b + root) / (2.0 * a);

        if (t_min < t1 and t1 < t_max) {
            t = t1;
        } else if (t_min < t2 and t2 < t_max) {
            t = t2;
        } else {
            return null;
        }

        const point: Vec3 = o.add(d.scale(t));
        const normal: UnitVec3 = (UnitVec3.normalize(point.sub(center)));
        return Hit{
            .t = t,
            .point = point,
            .normal = normal,
            .front_face = true,
            .material = self.material,
        };
    }
};
