const std = @import("std");
const helpers = @import("../helpers/helpers.zig");

/// Represents an RGB color in **linear, scene-referred floating-point space**.
///
/// This type is intended for **color and light computation**, not storage or output.
/// Values are not clamped and may exceed the range [0.0, 1.0].
///
/// Typical uses include:
/// - Lighting accumulation
/// - BRDF evaluation
/// - Reflections and multi-bounce light transport
/// - HDR rendering pipelines
///
/// Invariants:
/// - Components may be any finite `f64` value.
/// - Values greater than 1.0 are valid and expected during computation.
/// - No implicit clamping or normalization is performed.
///
/// Notes:
/// - This type deliberately does **not** enforce bounds.
/// - Clamping and quantization occur only when converting to output formats
///   such as `ColorRGB8`.
///
/// Color space:
/// - Linear RGB (not gamma-encoded).
///
pub const ColorRGBf = struct {
    r: f64,
    g: f64,
    b: f64,
};

pub fn colorToPixel(color: ColorRGBf) [3]u8 {
    return .{
        helpers.floatToU8(color.r),
        helpers.floatToU8(color.g),
        helpers.floatToU8(color.b),
    };
}

pub fn colorReflected(color: ColorRGBf, ray_color: ColorRGBf, reflect: f64) ColorRGBf {
    const local_lighting = 1.0 - helpers.clamp01(reflect);
    return ColorRGBf{
        .r = color.r * local_lighting + ray_color.r * reflect,
        .g = color.g * local_lighting + ray_color.g * reflect,
        .b = color.b * local_lighting + ray_color.b * reflect,
    };
}

/// Represents an RGB color in **8-bit per-channel integer format**.
///
/// This type is intended for **storage and output**, such as:
/// - Framebuffers
/// - Image files
/// - UI or display-referred color values
///
/// Component range:
/// - Each channel is stored as a `u8` in the range [0, 255].
///
/// Notes:
/// - This type is not suitable for color computation.
/// - Precision is limited to 8 bits per channel.
/// - All quantization and clamping must occur before or during construction.
///
/// Conversion:
/// - Use `fromFloat` to convert from `ColorRGBf`.
/// - Conversion clamps values to [0.0, 1.0] and maps them to [0, 255].
///
pub const ColorRGB8 = struct {
    r: u8,
    g: u8,
    b: u8,

    /// Converts a floating-point RGB color into an 8-bit per-channel color.
    ///
    /// This function represents a **domain boundary** between:
    /// - Continuous, linear light computation (`ColorRGBf`)
    /// - Discrete, display-ready pixel storage (`ColorRGB8`)
    ///
    /// Behavior:
    /// - Each component is clamped to the range [0.0, 1.0].
    /// - The clamped value is scaled to [0, 255].
    /// - The result is truncated toward zero.
    ///
    /// Preconditions:
    /// - `color.r`, `color.g`, and `color.b` must be finite.
    ///
    pub fn fromFloat(color: ColorRGBf) ColorRGB8 {
        return .{
            .r = helpers.floatToU8(color.r),
            .g = helpers.floatToU8(color.g),
            .b = helpers.floatToU8(color.b),
        };
    }
};

pub const Material = struct {
    color: ColorRGBf,
    reflectivity: f64,
};

pub const Pixel = struct {
    u: u32,
    v: u32,
    color: ColorRGBf,
};

pub const BLACK = ColorRGBf{ .r = 0.0, .g = 0.0, .b = 0.0 };
