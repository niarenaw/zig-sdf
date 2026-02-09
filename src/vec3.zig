const std = @import("std");

pub const Vec3 = @Vector(3, f32);

/// Convenience constructor for Vec3.
pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return .{ x, y, z };
}

/// Broadcast a scalar to all three components.
pub fn splat(s: f32) Vec3 {
    return @splat(s);
}

pub fn dot(a: Vec3, b: Vec3) f32 {
    return @reduce(.Add, a * b);
}

pub fn cross(a: Vec3, b: Vec3) Vec3 {
    // a × b = (a1*b2 - a2*b1, a2*b0 - a0*b2, a0*b1 - a1*b0)
    const a_yzx = @shuffle(f32, a, undefined, [3]i32{ 1, 2, 0 });
    const a_zxy = @shuffle(f32, a, undefined, [3]i32{ 2, 0, 1 });
    const b_yzx = @shuffle(f32, b, undefined, [3]i32{ 1, 2, 0 });
    const b_zxy = @shuffle(f32, b, undefined, [3]i32{ 2, 0, 1 });
    return a_yzx * b_zxy - a_zxy * b_yzx;
}

pub fn length(v: Vec3) f32 {
    return @sqrt(dot(v, v));
}

pub fn normalize(v: Vec3) Vec3 {
    const len = length(v);
    if (len == 0.0) return splat(0.0);
    return v / splat(len);
}

/// Reflect incident vector v around normal n.
pub fn reflect(v: Vec3, n: Vec3) Vec3 {
    return v - splat(2.0 * dot(v, n)) * n;
}

/// Linear interpolation between a and b by factor t.
pub fn mix(a: Vec3, b: Vec3, t: f32) Vec3 {
    const t_vec = splat(t);
    return a * (splat(1.0) - t_vec) + b * t_vec;
}

pub fn min_v(a: Vec3, b: Vec3) Vec3 {
    return @min(a, b);
}

pub fn max_v(a: Vec3, b: Vec3) Vec3 {
    return @max(a, b);
}

pub fn abs_v(v: Vec3) Vec3 {
    return @abs(v);
}

// ── Tests ───────────────────────────────────────────────────────────────

const expect = std.testing.expect;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const eps = 1e-6;

fn expectVec3Approx(actual: Vec3, expected: Vec3) !void {
    try expectApproxEqAbs(actual[0], expected[0], eps);
    try expectApproxEqAbs(actual[1], expected[1], eps);
    try expectApproxEqAbs(actual[2], expected[2], eps);
}

test "vec3 constructor" {
    const v = vec3(1.0, 2.0, 3.0);
    try expectApproxEqAbs(v[0], 1.0, eps);
    try expectApproxEqAbs(v[1], 2.0, eps);
    try expectApproxEqAbs(v[2], 3.0, eps);
}

test "splat" {
    const v = splat(5.0);
    try expectVec3Approx(v, vec3(5.0, 5.0, 5.0));
}

test "dot product" {
    try expectApproxEqAbs(dot(vec3(1, 0, 0), vec3(0, 1, 0)), 0.0, eps);
    try expectApproxEqAbs(dot(vec3(1, 2, 3), vec3(4, 5, 6)), 32.0, eps);
    try expectApproxEqAbs(dot(vec3(1, 0, 0), vec3(1, 0, 0)), 1.0, eps);
}

test "cross product" {
    // x × y = z
    try expectVec3Approx(cross(vec3(1, 0, 0), vec3(0, 1, 0)), vec3(0, 0, 1));
    // y × x = -z
    try expectVec3Approx(cross(vec3(0, 1, 0), vec3(1, 0, 0)), vec3(0, 0, -1));
    // parallel vectors → zero
    try expectVec3Approx(cross(vec3(1, 0, 0), vec3(2, 0, 0)), vec3(0, 0, 0));
    // general case
    try expectVec3Approx(cross(vec3(1, 2, 3), vec3(4, 5, 6)), vec3(-3, 6, -3));
}

test "length" {
    try expectApproxEqAbs(length(vec3(3, 4, 0)), 5.0, eps);
    try expectApproxEqAbs(length(vec3(1, 0, 0)), 1.0, eps);
    try expectApproxEqAbs(length(vec3(0, 0, 0)), 0.0, eps);
    try expectApproxEqAbs(length(vec3(1, 1, 1)), @sqrt(3.0), eps);
}

test "normalize" {
    const n = normalize(vec3(3, 0, 0));
    try expectVec3Approx(n, vec3(1, 0, 0));
    try expectApproxEqAbs(length(n), 1.0, eps);

    const n2 = normalize(vec3(1, 1, 1));
    try expectApproxEqAbs(length(n2), 1.0, eps);

    // Zero vector stays zero.
    try expectVec3Approx(normalize(vec3(0, 0, 0)), vec3(0, 0, 0));
}

test "reflect" {
    // Reflecting (1, -1, 0) around the up normal (0, 1, 0) → (1, 1, 0).
    const r = reflect(vec3(1, -1, 0), vec3(0, 1, 0));
    try expectVec3Approx(r, vec3(1, 1, 0));
}

test "mix (lerp)" {
    try expectVec3Approx(mix(vec3(0, 0, 0), vec3(10, 10, 10), 0.0), vec3(0, 0, 0));
    try expectVec3Approx(mix(vec3(0, 0, 0), vec3(10, 10, 10), 1.0), vec3(10, 10, 10));
    try expectVec3Approx(mix(vec3(0, 0, 0), vec3(10, 10, 10), 0.5), vec3(5, 5, 5));
}

test "min_v and max_v" {
    const a = vec3(1, 5, 3);
    const b = vec3(4, 2, 6);
    try expectVec3Approx(min_v(a, b), vec3(1, 2, 3));
    try expectVec3Approx(max_v(a, b), vec3(4, 5, 6));
}

test "abs_v" {
    try expectVec3Approx(abs_v(vec3(-1, -2, -3)), vec3(1, 2, 3));
    try expectVec3Approx(abs_v(vec3(1, -2, 3)), vec3(1, 2, 3));
}
