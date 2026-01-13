const c = @import("../helpers/const.zig");
const std = @import("std");
const assert = std.debug.assert;

const VecError = error{
    ZeroLength,
};

const Vec3 = struct {
    x: f64,
    y: f64,
    z: f64,

    pub fn new(x: f64, y: f64, z: f64) Vec3 {
        return Vec3.init(x, y, z);
    }

    fn init(x: f64, y: f64, z: f64) Vec3 {
        return Vec3{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub fn len(self: Vec3) f64 {
        return std.math.sqrt(self.len_sq());
    }

    pub fn len_sq(self: Vec3) f64 {
        return self.x * self.x + self.y * self.y + self.z * self.z;
    }

    pub fn cross(a: Vec3, b: Vec3) Vec3 {
        return Vec3.new(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x,
        );
    }

    pub fn dot(a: Vec3, b: Vec3) f64 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn scale(a: Vec3, s: f64) Vec3 {
        return Vec3.init(a.x * s, a.y * s, a.z * s);
    }
};

const UnitVec3 = struct {
    x: f64,
    y: f64,
    z: f64,

    fn init(x: f64, y: f64, z: f64) VecError!UnitVec3 {
        const len: f64 = std.math.sqrt(x * x + y * y + z * z);
        if (len < c.epsilon) return VecError.ZeroLength;
        return UnitVec3{
            .x = x / len,
            .y = y / len,
            .z = z / len,
        };
    }

    pub fn new(x: f64, y: f64, z: f64) VecError!UnitVec3 {
        return UnitVec3.init(x, y, z);
    }

    pub fn dot(a: UnitVec3, b: UnitVec3) f64 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub fn cross(a: UnitVec3, b: UnitVec3) Vec3 {
        return Vec3.cross(Vec3.new(a.x, a.y, a.z), Vec3.new(b.x, b.y, b.z));
    }

    pub fn normalize(a: Vec3) VecError!UnitVec3 {
        if (a.len_sq() < c.epsilon * c.epsilon) return VecError.ZeroLength;
        return UnitVec3.init(a.x, a.y, a.z);
    }
};
