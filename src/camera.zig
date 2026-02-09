const std = @import("std");
const v = @import("vec3.zig");
const Vec3 = v.Vec3;

/// Ray used for marching through the scene.
pub const Ray = struct {
    origin: Vec3,
    dir: Vec3,
};

/// Orbit camera parameters.
pub const Camera = struct {
    yaw: f32, // Horizontal rotation (radians)
    pitch: f32, // Vertical rotation (radians)
    distance: f32, // Distance from target
    target: Vec3, // Point the camera orbits around
    fov: f32, // Field of view multiplier
};

/// View matrix represented as three orthonormal basis vectors.
pub const LookAtMatrix = struct {
    right: Vec3,
    up: Vec3,
    forward: Vec3,
};

/// Compute camera eye position from spherical coordinates.
pub fn eyePosition(camera: Camera) Vec3 {
    const cos_pitch = @cos(camera.pitch);
    const sin_pitch = @sin(camera.pitch);
    const cos_yaw = @cos(camera.yaw);
    const sin_yaw = @sin(camera.yaw);

    const x = camera.distance * cos_pitch * sin_yaw;
    const y = camera.distance * sin_pitch;
    const z = camera.distance * cos_pitch * cos_yaw;

    return camera.target + v.vec3(x, y, z);
}

/// Construct a lookAt matrix from eye, target, and up vector.
/// Returns an orthonormal basis: right, up, forward.
pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) LookAtMatrix {
    const forward = v.normalize(target - eye);
    const right = v.normalize(v.cross(forward, up));
    const cam_up = v.cross(right, forward);

    return LookAtMatrix{
        .right = right,
        .up = cam_up,
        .forward = forward,
    };
}

/// Generate a ray for normalized screen coordinates (u, v in -1..1).
pub fn getRay(camera: Camera, u: f32, vv: f32, aspect: f32) Ray {
    const eye = eyePosition(camera);
    const mat = lookAt(eye, camera.target, v.vec3(0, 1, 0));

    // Transform screen-space direction through camera basis.
    // Z is positive because mat.forward already points toward the target.
    const dir_local = v.vec3(u * camera.fov * aspect, vv * camera.fov, 1.0);
    const dir_world = v.normalize(
        mat.right * v.splat(dir_local[0]) +
            mat.up * v.splat(dir_local[1]) +
            mat.forward * v.splat(dir_local[2]),
    );

    return Ray{
        .origin = eye,
        .dir = dir_world,
    };
}

/// Create a default camera suitable for viewing a scene at the origin.
pub fn defaultCamera() Camera {
    return Camera{
        .yaw = 0.0,
        .pitch = 0.3,
        .distance = 3.0,
        .target = v.vec3(0, 0, 0),
        .fov = 1.0,
    };
}

// ── Tests ───────────────────────────────────────────────────────────────

const expect = std.testing.expect;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const eps = 1e-4;

fn expectVec3Approx(actual: Vec3, expected: Vec3) !void {
    try expectApproxEqAbs(actual[0], expected[0], eps);
    try expectApproxEqAbs(actual[1], expected[1], eps);
    try expectApproxEqAbs(actual[2], expected[2], eps);
}

test "eyePosition: basic spherical to cartesian" {
    const cam = Camera{
        .yaw = 0.0,
        .pitch = 0.0,
        .distance = 5.0,
        .target = v.vec3(0, 0, 0),
        .fov = 1.0,
    };
    const eye = eyePosition(cam);
    // pitch=0, yaw=0 → looking along +z axis
    try expectVec3Approx(eye, v.vec3(0, 0, 5));
}

test "eyePosition: with pitch" {
    const cam = Camera{
        .yaw = 0.0,
        .pitch = std.math.pi / 2.0, // 90 degrees up
        .distance = 3.0,
        .target = v.vec3(0, 0, 0),
        .fov = 1.0,
    };
    const eye = eyePosition(cam);
    // pitch=90° → straight up (+y)
    try expectVec3Approx(eye, v.vec3(0, 3, 0));
}

test "eyePosition: with yaw" {
    const cam = Camera{
        .yaw = std.math.pi / 2.0, // 90 degrees rotation
        .pitch = 0.0,
        .distance = 4.0,
        .target = v.vec3(0, 0, 0),
        .fov = 1.0,
    };
    const eye = eyePosition(cam);
    // yaw=90° → along +x axis
    try expectVec3Approx(eye, v.vec3(4, 0, 0));
}

test "eyePosition: with non-zero target" {
    const cam = Camera{
        .yaw = 0.0,
        .pitch = 0.0,
        .distance = 2.0,
        .target = v.vec3(1, 2, 3),
        .fov = 1.0,
    };
    const eye = eyePosition(cam);
    // offset by target position
    try expectVec3Approx(eye, v.vec3(1, 2, 5));
}

test "lookAt: produces orthonormal basis" {
    const eye = v.vec3(0, 0, 3);
    const target = v.vec3(0, 0, 0);
    const up = v.vec3(0, 1, 0);

    const mat = lookAt(eye, target, up);

    // Check orthogonality: dot products should be ~0
    try expectApproxEqAbs(v.dot(mat.right, mat.up), 0.0, eps);
    try expectApproxEqAbs(v.dot(mat.right, mat.forward), 0.0, eps);
    try expectApproxEqAbs(v.dot(mat.up, mat.forward), 0.0, eps);

    // Check normalization: all vectors should have length ~1
    try expectApproxEqAbs(v.length(mat.right), 1.0, eps);
    try expectApproxEqAbs(v.length(mat.up), 1.0, eps);
    try expectApproxEqAbs(v.length(mat.forward), 1.0, eps);
}

test "lookAt: forward points from eye to target" {
    const eye = v.vec3(0, 0, 5);
    const target = v.vec3(0, 0, 0);
    const up = v.vec3(0, 1, 0);

    const mat = lookAt(eye, target, up);

    // Forward should point along -z (toward origin from +z)
    try expectVec3Approx(mat.forward, v.vec3(0, 0, -1));
}

test "getRay: center pixel points along forward" {
    const cam = defaultCamera();
    const aspect: f32 = 1.0;

    // Center of screen (u=0, v=0)
    const ray = getRay(cam, 0.0, 0.0, aspect);

    // Ray should point generally toward the target
    const to_target = v.normalize(cam.target - eyePosition(cam));
    const alignment = v.dot(ray.dir, to_target);

    // Should be pointing roughly toward target (high positive dot product).
    // Not exactly 1.0 because the FOV spreads center rays slightly.
    try expect(alignment > 0.7);
}

test "getRay: different screen positions produce different directions" {
    const cam = defaultCamera();
    const aspect: f32 = 1.0;

    const ray_left = getRay(cam, -1.0, 0.0, aspect);
    const ray_right = getRay(cam, 1.0, 0.0, aspect);

    // Left and right rays should diverge
    const similarity = v.dot(ray_left.dir, ray_right.dir);
    try expect(similarity < 0.99);
}

test "getRay: rays are normalized" {
    const cam = defaultCamera();
    const aspect: f32 = 1.6;

    const ray = getRay(cam, 0.5, 0.3, aspect);

    // Direction should be unit length
    try expectApproxEqAbs(v.length(ray.dir), 1.0, eps);
}

test "defaultCamera: produces valid camera" {
    const cam = defaultCamera();

    try expect(cam.distance > 0.0);
    try expect(cam.fov > 0.0);

    // Should be able to compute eye position without issues
    const eye = eyePosition(cam);
    try expect(v.length(eye - cam.target) > 0.0);
}
