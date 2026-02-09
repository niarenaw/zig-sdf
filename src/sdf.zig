const std = @import("std");
const v = @import("vec3.zig");
const Vec3 = v.Vec3;
const vec3 = v.vec3;

// ── Primitives ──────────────────────────────────────────────────────────

/// Signed distance to a sphere centered at the origin.
pub fn sphere(p: Vec3, radius: f32) f32 {
    return v.length(p) - radius;
}

/// Signed distance to an axis-aligned box centered at the origin.
pub fn box(p: Vec3, half_extents: Vec3) f32 {
    const q = v.abs_v(p) - half_extents;
    const outside = v.length(v.max_v(q, v.splat(0.0)));
    const inside = @min(@reduce(.Max, q), @as(f32, 0.0));
    return outside + inside;
}

/// Signed distance to an infinite plane defined by a normal and offset.
pub fn plane(p: Vec3, normal: Vec3, offset: f32) f32 {
    return v.dot(p, normal) + offset;
}

/// Signed distance to a torus lying in the xz-plane, centered at the origin.
pub fn torus(p: Vec3, radius_major: f32, radius_minor: f32) f32 {
    const xz_len = @sqrt(p[0] * p[0] + p[2] * p[2]);
    const q_x = xz_len - radius_major;
    const q_y = p[1];
    return @sqrt(q_x * q_x + q_y * q_y) - radius_minor;
}

/// Signed distance to a capped cylinder along the y-axis, centered at the origin.
pub fn cylinder(p: Vec3, radius: f32, half_height: f32) f32 {
    const xz_len = @sqrt(p[0] * p[0] + p[2] * p[2]);
    const d_x = @abs(xz_len) - radius;
    const d_y = @abs(p[1]) - half_height;
    const outside = @sqrt(@max(d_x, 0.0) * @max(d_x, 0.0) + @max(d_y, 0.0) * @max(d_y, 0.0));
    const inside = @min(@max(d_x, d_y), @as(f32, 0.0));
    return outside + inside;
}

// ── Tests ───────────────────────────────────────────────────────────────

const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const eps = 1e-4;

test "sphere: surface, inside, outside" {
    try expectApproxEqAbs(sphere(vec3(1, 0, 0), 1.0), 0.0, eps);
    try expectApproxEqAbs(sphere(vec3(0, 0, 0), 1.0), -1.0, eps);
    try expectApproxEqAbs(sphere(vec3(2, 0, 0), 1.0), 1.0, eps);
}

test "box: surface, inside, outside" {
    const half = vec3(1, 1, 1);
    try expectApproxEqAbs(box(vec3(1, 0, 0), half), 0.0, eps);
    try expectApproxEqAbs(box(vec3(0, 0, 0), half), -1.0, eps);
    try expectApproxEqAbs(box(vec3(2, 0, 0), half), 1.0, eps);
}

test "plane: above, on, below" {
    const up = vec3(0, 1, 0);
    try expectApproxEqAbs(plane(vec3(0, 1, 0), up, 0.0), 1.0, eps);
    try expectApproxEqAbs(plane(vec3(0, 0, 0), up, 0.0), 0.0, eps);
    try expectApproxEqAbs(plane(vec3(0, -1, 0), up, 0.0), -1.0, eps);
}

test "torus: on ring center, outside" {
    try expectApproxEqAbs(torus(vec3(2, 0, 0), 2.0, 0.5), -0.5, eps);
    try expectApproxEqAbs(torus(vec3(2.5, 0, 0), 2.0, 0.5), 0.0, eps);
    try expectApproxEqAbs(torus(vec3(3, 0, 0), 2.0, 0.5), 0.5, eps);
}

test "cylinder: on surface, inside, outside" {
    try expectApproxEqAbs(cylinder(vec3(1, 0, 0), 1.0, 1.0), 0.0, eps);
    try expectApproxEqAbs(cylinder(vec3(0, 0, 0), 1.0, 1.0), -1.0, eps);
    try expectApproxEqAbs(cylinder(vec3(2, 0, 0), 1.0, 1.0), 1.0, eps);
}
