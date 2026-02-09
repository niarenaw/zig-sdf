const v = @import("vec3.zig");
const Vec3 = v.Vec3;

const max_steps: usize = 64;
const max_dist: f32 = 100.0;
const surface_eps: f32 = 0.001;

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
