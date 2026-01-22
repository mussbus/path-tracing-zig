const std = @import("std");

const tracy = @import("tracy");
const Zone = tracy.Zone;

const consts = @import("../helpers/const.zig");
const screen = @import("../screen/screen.zig");
const ColorRGBf = screen.ColorRGBf;
const Material = screen.Material;
const ray_file = @import("ray.zig");
const Ray = ray_file.Ray;
const vec = @import("vec.zig");
const Vec3 = vec.Vec3;
const UnitVec3 = vec.UnitVec3;

pub const Hit = struct {
    t: f64,
    point: Vec3,
    normal: UnitVec3,
    front_face: bool,
    material: Material,
};

pub const Plane = struct {
    point: Vec3,
    normal: UnitVec3,
    material: Material,

    pub inline fn intersect(self: Plane, ray: Ray, t_min: f64, t_max: f64) ?Hit {
        const zone = Zone.begin(.{
            .name = "Plane::intersect",
            .src = @src(),
            .color = .cyan,
        });
        defer zone.end();
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

    pub inline fn intersect(self: Sphere, ray: Ray, t_min: f64, t_max: f64) ?Hit {
        const zone = Zone.begin(.{
            .name = "Sphere::intersect",
            .src = @src(),
            .color = .magenta,
        });
        defer zone.end();
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

const Entity = union(enum) {
    sphere: Sphere,
    plane: Plane,

    pub fn intersect(self: Entity, ray: Ray, t_min: f64, t_max: f64) ?Hit {
        return switch (self) {
            .sphere => |s| s.intersect(ray, t_min, t_max),
            .plane => |p| p.intersect(ray, t_min, t_max),
        };
    }
};

pub const Scene = struct {
    entities: []const Entity,

    pub inline fn intersect(self: Scene, ray: Ray, t_min: f64, t_max: f64) ?Hit {
        var closest_hit: ?Hit = null;
        var t_max_local = t_max;

        for (self.entities) |object| {
            const hit: ?Hit = object.intersect(ray, t_min, t_max_local);
            if (hit) |h| {
                if (closest_hit == null or h.t < t_max_local) {
                    t_max_local = h.t;
                    closest_hit = h;
                }
            }
        }
        return closest_hit;
    }
};

const scene_entities = [_]Entity{
    .{
        .plane = Plane{
            .point = Vec3.init(0.0, 0.0, -10.0),
            .normal = UnitVec3.init(0.0, 1.0, 1.0),
            .material = Material{
                .color = ColorRGBf{ .r = 0.0, .g = 1.0, .b = 0.0 },
                .reflectivity = 0.1,
            },
        },
    },
    .{
        .plane = Plane{
            .point = Vec3.init(0.0, 0.0, 10.0),
            .normal = UnitVec3.init(0.0, 1.0, -1.0),
            .material = Material{
                .color = ColorRGBf{ .r = 0.0, .g = 1.0, .b = 1.0 },
                .reflectivity = 0.1,
            },
        },
    },
    .{
        .plane = Plane{
            .point = Vec3.init(0.0, -2.0, 0.0),
            .normal = UnitVec3.init(0.0, 1.0, 0.0),
            .material = Material{
                .color = ColorRGBf{ .r = 0.0, .g = 0.0, .b = 0.0 },
                .reflectivity = 0.06,
            },
        },
    },
    .{
        .plane = Plane{
            .point = Vec3.init(10.0, 0.0, 0.0),
            .normal = UnitVec3.init(-1.0, 1.0, 0.0),
            .material = Material{
                .color = ColorRGBf{ .r = 0.0, .g = 0.0, .b = 1.0 },
                .reflectivity = 0.1,
            },
        },
    },
    .{
        .plane = Plane{
            .point = Vec3.init(-10.0, 0.0, 0.0),
            .normal = UnitVec3.init(1.0, 1.0, 0.0),
            .material = Material{
                .color = ColorRGBf{ .r = 1.0, .g = 0.0, .b = 0.0 },
                .reflectivity = 0.1,
            },
        },
    },
    .{
        .sphere = Sphere{
            .center = Vec3.init(0.0, -2.0, -7.0),
            .radius = 3.0,
            .material = Material{
                .color = ColorRGBf{ .r = 1.0, .g = 1.0, .b = 1.0 },
                .reflectivity = 0.4,
            },
        },
    },
    .{
        .sphere = Sphere{
            .center = Vec3.init(0.0, 3.0, 8.0),
            .radius = 7.0,
            .material = Material{
                .color = ColorRGBf{ .r = 0.0, .g = 1.0, .b = 0.0 },
                .reflectivity = 0.8,
            },
        },
    },
    .{
        .sphere = Sphere{
            .center = Vec3.init(-4.0, 1.0, -9.0),
            .radius = 3.0,
            .material = Material{
                .color = ColorRGBf{ .r = 1.0, .g = 0.0, .b = 0.0 },
                .reflectivity = 0.15,
            },
        },
    },
    .{
        .sphere = Sphere{
            .center = Vec3.init(6.0, 3.0, -20.0),
            .radius = 10.0,
            .material = Material{
                .color = ColorRGBf{ .r = 1.0, .g = 0.0, .b = 0.0 },
                .reflectivity = 0.5,
            },
        },
    },
};

pub const scene = Scene{
    .entities = &scene_entities,
};
