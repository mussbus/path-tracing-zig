const c = @import("../helpers/constants.zig");
const std = @import("std");
const assert = std.debug.assert;

pub const VecError = error{
    ZeroLength,
};

// TODO switch interface to [3]f64 instead of .x, .y, .z
// removes branching in component function
pub const Vec3 = struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn init(x: f64, y: f64, z: f64) Vec3 {
        return Vec3{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub fn component(self: Vec3, axis: u32) f64 {
        switch (axis) {
            0 => return self.x,
            1 => return self.y,
            2 => return self.z,
            else => unreachable,
        }
    }

    pub fn len(self: Vec3) f64 {
        return std.math.sqrt(self.len_sq());
    }

    pub fn len_sq(self: Vec3) f64 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return Vec3.init(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x,
        );
    }

    pub fn dot(a: Vec3, b: Vec3) f64 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self.x + other.x, self.y + other.y, self.z + other.z);
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return Vec3.init(self.x - other.x, self.y - other.y, self.z - other.z);
    }

    pub fn scale(self: Vec3, s: f64) Vec3 {
        return Vec3.init(self.x * s, self.y * s, self.z * s);
    }
};

pub const UnitVec3 = struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn init(x: f64, y: f64, z: f64) UnitVec3 {
        const len_sq = x * x + y * y + z * z;
        std.debug.assert(len_sq > c.epsilon * c.epsilon);
        const len = std.math.sqrt(len_sq);

        return UnitVec3{
            .x = x / len,
            .y = y / len,
            .z = z / len,
        };
    }

    pub fn asVec3(self: UnitVec3) Vec3 {
        return Vec3.init(self.x, self.y, self.z);
    }

    pub fn dot(a: UnitVec3, b: UnitVec3) f64 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: UnitVec3, b: UnitVec3) Vec3 {
        return Vec3.init(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x,
        );
    }

    pub fn normalize(a: Vec3) UnitVec3 {
        std.debug.assert(a.len_sq() > c.epsilon * c.epsilon);
        return UnitVec3.init(a.x, a.y, a.z);
    }

    pub fn scale(self: UnitVec3, s: f64) Vec3 {
        return Vec3.init(self.x * s, self.y * s, self.z * s);
    }

    pub fn sub(self: UnitVec3, other: UnitVec3) Vec3 {
        return Vec3.init(self.x - other.x, self.y - other.y, self.z - other.z);
    }

    pub fn flip(self: UnitVec3) UnitVec3 {
        return UnitVec3.init(-self.x, -self.y, -self.z);
    }
};
