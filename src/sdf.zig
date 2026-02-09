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

// ── Operations ─────────────────────────────────────────────────────────

pub fn op_union(d1: f32, d2: f32) f32 {
    return @min(d1, d2);
}

pub fn op_intersection(d1: f32, d2: f32) f32 {
    return @max(d1, d2);
}

pub fn op_subtraction(d1: f32, d2: f32) f32 {
    return @max(-d1, d2);
}

/// Polynomial smooth minimum for organic blending between two SDFs.
pub fn op_smooth_union(d1: f32, d2: f32, k: f32) f32 {
    const h = @max(k - @abs(d1 - d2), 0.0) / k;
    return @min(d1, d2) - h * h * k * 0.25;
}

pub fn op_smooth_subtraction(d1: f32, d2: f32, k: f32) f32 {
    const h = @max(k - @abs(-d1 - d2), 0.0) / k;
    return @max(-d1, d2) + h * h * k * 0.25;
}

// ── Domain Transforms ──────────────────────────────────────────────────

pub fn translate(p: Vec3, offset: Vec3) Vec3 {
    return p - offset;
}

pub fn rotate_y(p: Vec3, angle: f32) Vec3 {
    const c = @cos(angle);
    const s = @sin(angle);
    return vec3(c * p[0] + s * p[2], p[1], -s * p[0] + c * p[2]);
}

pub fn repeat(p: Vec3, spacing: f32) Vec3 {
    const half = v.splat(spacing * 0.5);
    return @mod(p + half, v.splat(spacing)) - half;
}

// ── Comptime Scene Composition ─────────────────────────────────────────
//
// Each helper captures comptime parameters via an inner struct namespace,
// returning a `fn(Vec3) f32` that the compiler monomorphizes into the
// ray marcher with zero runtime overhead.

pub fn sphere_scene(comptime radius: f32) fn (Vec3) f32 {
    return struct {
        fn f(p: Vec3) f32 {
            return sphere(p, radius);
        }
    }.f;
}

pub fn box_scene(comptime hx: f32, comptime hy: f32, comptime hz: f32) fn (Vec3) f32 {
    return struct {
        fn f(p: Vec3) f32 {
            return box(p, vec3(hx, hy, hz));
        }
    }.f;
}

pub fn translated(comptime inner: fn (Vec3) f32, comptime offset: Vec3) fn (Vec3) f32 {
    return struct {
        fn f(p: Vec3) f32 {
            return inner(translate(p, offset));
        }
    }.f;
}

pub fn rotated_y(comptime inner: fn (Vec3) f32, comptime angle: f32) fn (Vec3) f32 {
    return struct {
        fn f(p: Vec3) f32 {
            return inner(rotate_y(p, angle));
        }
    }.f;
}

pub fn union_of(comptime a: fn (Vec3) f32, comptime b: fn (Vec3) f32) fn (Vec3) f32 {
    return struct {
        fn f(p: Vec3) f32 {
            return op_union(a(p), b(p));
        }
    }.f;
}

pub fn smooth_union_of(comptime a: fn (Vec3) f32, comptime b: fn (Vec3) f32, comptime k: f32) fn (Vec3) f32 {
    return struct {
        fn f(p: Vec3) f32 {
            return op_smooth_union(a(p), b(p), k);
        }
    }.f;
}

pub fn subtraction_of(comptime a: fn (Vec3) f32, comptime b: fn (Vec3) f32) fn (Vec3) f32 {
    return struct {
        fn f(p: Vec3) f32 {
            return op_subtraction(a(p), b(p));
        }
    }.f;
}

pub fn repeated(comptime inner: fn (Vec3) f32, comptime spacing: f32) fn (Vec3) f32 {
    return struct {
        fn f(p: Vec3) f32 {
            return inner(repeat(p, spacing));
        }
    }.f;
}

// ── Demo Scenes ────────────────────────────────────────────────────────

/// Organic blobs: smooth union of several offset spheres.
pub const scene_blobs = blk: {
    const a = translated(sphere_scene(0.6), vec3(-0.5, 0.0, 0.0));
    const b = translated(sphere_scene(0.5), vec3(0.5, 0.3, 0.0));
    const c = translated(sphere_scene(0.55), vec3(0.0, -0.4, 0.4));
    const d = translated(sphere_scene(0.45), vec3(0.2, 0.5, -0.3));
    break :blk smooth_union_of(smooth_union_of(a, b, 0.5), smooth_union_of(c, d, 0.5), 0.5);
};

/// Hollow box: a sphere carved out of a rounded box.
pub const scene_difference = subtraction_of(
    sphere_scene(1.1),
    box_scene(0.8, 0.8, 0.8),
);

/// Infinite grid of cylinders resting on a ground plane.
pub const scene_pillars = blk: {
    const pillar = repeated(
        rotated_y(
            struct {
                fn f(p: Vec3) f32 {
                    return cylinder(p, 0.2, 0.6);
                }
            }.f,
            0.0,
        ),
        2.0,
    );
    const ground = struct {
        fn f(p: Vec3) f32 {
            return plane(p, vec3(0, 1, 0), 0.6);
        }
    }.f;
    break :blk union_of(pillar, ground);
};

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

test "op_union: picks closer surface" {
    try expectApproxEqAbs(op_union(1.0, 2.0), 1.0, eps);
    try expectApproxEqAbs(op_union(-0.5, 0.3), -0.5, eps);
}

test "op_intersection: picks farther surface" {
    try expectApproxEqAbs(op_intersection(1.0, 2.0), 2.0, eps);
    try expectApproxEqAbs(op_intersection(-0.5, 0.3), 0.3, eps);
}

test "op_subtraction: carves first from second" {
    // Outside both → second distance dominates.
    try expectApproxEqAbs(op_subtraction(2.0, 1.0), 1.0, eps);
    // Inside first, outside second → max(-d1, d2).
    try expectApproxEqAbs(op_subtraction(-0.5, 0.3), 0.5, eps);
}

test "op_smooth_union: blends between surfaces" {
    // With distant surfaces, smooth union matches hard union.
    try expectApproxEqAbs(op_smooth_union(1.0, 5.0, 0.5), 1.0, eps);
    // Smooth blend pulls the result below the hard minimum when surfaces overlap.
    const smooth = op_smooth_union(0.3, 0.3, 1.0);
    try std.testing.expect(smooth < 0.3);
}

test "comptime scene: scene_blobs evaluates without error" {
    const d = scene_blobs(vec3(0, 0, 0));
    try std.testing.expect(d < 0.0); // Origin is inside the blobs.
}

test "comptime scene: scene_difference carves sphere from box" {
    // Center is inside box but also inside sphere, so subtraction removes it.
    const d = scene_difference(vec3(0, 0, 0));
    try std.testing.expect(d > 0.0);
}
