const std = @import("std");

const tracy = @import("tracy");
const Zone = tracy.Zone;

const constants = @import("../helpers/constants.zig");
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
        if (@abs(dot) < constants.epsilon) return null;
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

    pub fn bounds(self: *const Sphere) AABB {
        const c = self.*.center;
        const r = self.*.radius;
        // const r = self.*.radius + constants.epsilon;
        const min = Vec3.init(c.x - r, c.y - r, c.z - r);
        const max = Vec3.init(c.x + r, c.y + r, c.z + r);
        return AABB{
            .min = min,
            .max = max,
        };
    }
};

const min_max = struct {
    min: f64,
    max: f64,
};

pub const AABB = struct {
    min: Vec3,
    max: Vec3,

    pub fn unionize(a: AABB, b: AABB) AABB {
        return AABB{
            .min = Vec3.init(@min(a.min.x, b.min.x), @min(a.min.y, b.min.y), @min(a.min.z, b.min.z)),
            .max = Vec3.init(@max(a.max.x, b.max.x), @max(a.max.y, b.max.y), @max(a.max.z, b.max.z)),
        };
    }

    pub fn hit(self: AABB, ray: Ray, t_min: f64, t_max: f64) ?f64 {
        const x = slab_interval(ray.origin.x, ray.direction.x, self.min.x, self.max.x);
        const y = slab_interval(ray.origin.y, ray.direction.y, self.min.y, self.max.y);
        const z = slab_interval(ray.origin.z, ray.direction.z, self.min.z, self.max.z);
        const t_enter = @max(x.min, y.min, z.min, t_min);
        const t_exit = @min(x.max, y.max, z.max, t_max);

        if (t_enter <= t_exit)
            return t_enter;
        return null;
    }

    inline fn slab_interval(origin: f64, direction: f64, min: f64, max: f64) min_max {
        if (@abs(direction) < constants.epsilon) {
            if (origin < min or origin > max) {
                return min_max{ .min = std.math.floatMax(f64), .max = -std.math.floatMax(f64) };
            } else {
                return min_max{ .min = -std.math.floatMax(f64), .max = std.math.floatMax(f64) };
            }
        }
        const t0 = (origin - min) / direction;
        const t1 = (origin - max) / direction;
        return min_max{ .min = @min(t0, t1), .max = @max(t0, t1) };
    }

    pub fn centroid(self: AABB) Vec3 {
        return self.min.add(self.max).scale(0.5);
    }
};

// TODO pass in centroids as a parameter? How to prevent recomputing every centroid?
pub const BVH = struct {
    root: *BVHNode,
    indices: []u32,

    pub fn build_bvh(scenery: *const Scene, allocator: std.mem.Allocator) !BVH {
        const indices: []u32 = try allocator.alloc(u32, scenery.*.entities.len);
        for (indices, 0..) |_, i| {
            indices[i] = @intCast(i);
        }
        const root: *BVHNode = try build_bvh_node(scenery, indices, 0, @as(u32, @intCast(indices.len)), allocator);

        return BVH{ .root = root, .indices = indices };
    }

    fn build_bvh_node(scenery: *const Scene, indices: []u32, start: u32, count: u32, allocator: std.mem.Allocator) !*BVHNode {
        const end: u32 = start + count - 1;
        var entity_index = indices[start];
        var bounds: AABB = scenery.*.entities[entity_index].bounds();
        var index = start + 1;
        while (index <= end) : (index += 1) {
            entity_index = indices[index];
            bounds = AABB.unionize(bounds, scenery.*.entities[entity_index].bounds());
        }

        if (count <= constants.leaf_threshold) {
            const leaf_node = try allocator.create(BVHNode);
            leaf_node.* = BVHNode{ .bounds = bounds, .data = .{ .leaf = .{
            .start = start, .count = count
            }  }};
            return leaf_node;
        }

        const x: f64 = bounds.max.x - bounds.min.x;
        const y: f64 = bounds.max.y - bounds.min.y;
        const z: f64 = bounds.max.z - bounds.min.z;

        var max: f64 = x;
        var axis: u32 = 0;

        if (y > max) {
            axis = 1;
            max = y;
        }
        if (z > max) {
            axis = 2;
            max = z;
        }

        const centroid: Vec3 = bounds.centroid();
        const midpoint: f64 = centroid.component(axis);
        var i: u32 = start;
        var j: u32 = end;

        var left_entity: u32 = indices[i];
        var right_entity: u32 = indices[j];

        while (i <= j) {
            if (scenery.*.entities[left_entity].bounds().centroid().component(axis) <= midpoint) {
                i += 1;
                left_entity = indices[i];
            } else if (scenery.*.entities[right_entity].bounds().centroid().component(axis) > midpoint) {
                j -= 1;
                right_entity = indices[j];
            } else {
                indices[i] = right_entity;
                indices[j] = left_entity;
                i += 1;
                j -= 1;
                left_entity = indices[i];
                right_entity = indices[j];
            }
        }

        var left: u32 = i - start;
        var right: u32 = count - left;

        if (left == 0 or left == count) {
            left = count / 2;
            right = count - left;
        }

        const l_node = try build_bvh_node(scenery, indices, start, left, allocator);
        const r_node = try build_bvh_node(scenery, indices, start + left, right, allocator);

        const node = try allocator.create(BVHNode);
        node.* = BVHNode{ .bounds = bounds, .data = .{ .internal = .{ .left = l_node, .right = r_node }} } ;
        return node;
    }
};

// TODO change struct size to be < 64 Bytes

pub const BVHNode = struct { bounds: AABB, data: union(enum) { leaf: struct {
    start: u32,
    count: u32,
}, internal: struct {
    left: *BVHNode,
    right: *BVHNode,
} } };

const Entity = union(enum) {
    sphere: Sphere,
    plane: Plane,
    // triangle: Triangle,

    pub fn intersect(self: Entity, ray: Ray, t_min: f64, t_max: f64) ?Hit {
        return switch (self) {
            .sphere => |s| s.intersect(ray, t_min, t_max),
            .plane => |p| p.intersect(ray, t_min, t_max),
            // .triangle => |t| t.intersect(ray, t_min, t_max),
        };
    }

    pub fn bounds(self: Entity) AABB {
        return switch (self) {
            .sphere => |s| s.bounds(),
            .plane => AABB{ .max = Vec3.init(1, 1, 1), .min = Vec3.init(0, 0, 0) },
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

    // pub fn generate_scene(allocator: std.mem.Allocator) Scene {

    // }
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
