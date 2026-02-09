const std = @import("std");
const v = @import("vec3.zig");
const Vec3 = v.Vec3;
const terminal = @import("terminal.zig");
const cam = @import("camera.zig");

const max_steps: usize = 64;
const max_dist: f32 = 100.0;
const surface_eps: f32 = 0.001;
const normal_eps: f32 = 0.0001;

pub const HitResult = struct {
    pos: Vec3,
    dist: f32,
    steps: usize,
};

/// Ray march along a ray using a comptime SDF. Returns hit info or null on miss.
pub fn march(origin: Vec3, dir: Vec3, comptime sdf: fn (Vec3) f32) ?HitResult {
    var t: f32 = 0.0;
    for (0..max_steps) |i| {
        const p = origin + v.splat(t) * dir;
        const d = sdf(p);
        if (d < surface_eps) {
            return .{ .pos = p, .dist = t, .steps = i };
        }
        t += d;
        if (t > max_dist) break;
    }
    return null;
}

/// Estimate surface normal at point p using central differences.
pub fn estimateNormal(p: Vec3, comptime sdf: fn (Vec3) f32) Vec3 {
    const x_offset = v.vec3(normal_eps, 0, 0);
    const y_offset = v.vec3(0, normal_eps, 0);
    const z_offset = v.vec3(0, 0, normal_eps);

    const grad_x = sdf(p + x_offset) - sdf(p - x_offset);
    const grad_y = sdf(p + y_offset) - sdf(p - y_offset);
    const grad_z = sdf(p + z_offset) - sdf(p - z_offset);

    return v.normalize(v.vec3(grad_x, grad_y, grad_z));
}

/// Calculate ambient occlusion by marching along the normal.
pub fn calcAO(pos: Vec3, normal: Vec3, comptime sdf: fn (Vec3) f32) f32 {
    const steps = 5;
    var occlusion: f32 = 0.0;
    const step_size: f32 = 0.01;

    for (0..steps) |i| {
        const step_dist = step_size * @as(f32, @floatFromInt(i + 1));
        const sample_pos = pos + v.splat(step_dist) * normal;
        const sample_dist = sdf(sample_pos);
        // Expected distance should equal step distance; deviation indicates occlusion.
        occlusion += (step_dist - sample_dist) / step_dist;
    }

    return 1.0 - @min(occlusion / @as(f32, @floatFromInt(steps)), 1.0);
}

/// Calculate soft shadows by marching toward the light.
pub fn calcSoftShadow(pos: Vec3, light_dir: Vec3, comptime sdf: fn (Vec3) f32) f32 {
    const max_t: f32 = 10.0;
    const softness: f32 = 8.0;
    var t: f32 = 0.02; // Start slightly offset to avoid self-intersection.
    var res: f32 = 1.0;

    while (t < max_t) {
        const p = pos + v.splat(t) * light_dir;
        const d = sdf(p);
        if (d < surface_eps) {
            return 0.0; // Hard shadow.
        }
        // Accumulate penumbra.
        res = @min(res, softness * d / t);
        t += d;
    }

    return @max(0.0, @min(1.0, res));
}

/// Compute lighting for a surface point.
pub fn shade(pos: Vec3, normal: Vec3, view_dir: Vec3, comptime sdf: fn (Vec3) f32) f32 {
    const light_pos = v.vec3(3.0, 4.0, 2.0);
    const light_dir = v.normalize(light_pos - pos);

    // Ambient term.
    const ambient: f32 = 0.08;

    // Diffuse term.
    const diffuse = @max(0.0, v.dot(normal, light_dir));

    // Specular term (Blinn-Phong).
    const half_vec = v.normalize(light_dir + view_dir);
    const spec_strength = @max(0.0, v.dot(normal, half_vec));
    const shininess: f32 = 32.0;
    const specular = std.math.pow(f32, spec_strength, shininess) * 0.5;

    // Ambient occlusion.
    const ao = calcAO(pos, normal, sdf);

    // Soft shadows.
    const shadow = calcSoftShadow(pos, light_dir, sdf);

    // Combine terms.
    const lighting = ambient + (diffuse + specular) * shadow * ao;
    return @min(1.0, lighting);
}

/// Render the scene into a framebuffer using the orbit camera.
pub fn renderFrame(
    fb: *terminal.FrameBuffer,
    comptime sdf_fn: fn (Vec3) f32,
    camera: cam.Camera,
) void {
    const fw: f32 = @floatFromInt(fb.width);
    const fh: f32 = @floatFromInt(fb.pixel_height);
    const aspect = fw / fh;

    for (0..fb.pixel_height) |y| {
        for (0..fb.width) |x| {
            const u = @as(f32, @floatFromInt(x)) / fw * 2.0 - 1.0;
            const vv = -(@as(f32, @floatFromInt(y)) / fh * 2.0 - 1.0);
            const ray = cam.getRay(camera, u, vv, aspect);

            if (march(ray.origin, ray.dir, sdf_fn)) |hit| {
                const normal = estimateNormal(hit.pos, sdf_fn);
                const view_dir = v.normalize(ray.origin - hit.pos);
                const brightness = shade(hit.pos, normal, view_dir, sdf_fn);
                terminal.setPixel(fb, x, y, terminal.brightnessToColor(brightness));
            }
            // Missed pixels stay at default black from createFrameBuffer.
        }
    }
}
