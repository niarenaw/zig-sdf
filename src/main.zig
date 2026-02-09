const std = @import("std");
const v = @import("vec3.zig");
const Vec3 = v.Vec3;
const sdf = @import("sdf.zig");
const render = @import("render.zig");
const terminal = @import("terminal.zig");

/// Scene SDF: a unit sphere at the origin.
fn sceneSphere(p: Vec3) f32 {
    return sdf.sphere(p, 1.0);
}

/// Scene SDF: a box at the origin (for testing shape swap).
fn sceneBox(p: Vec3) f32 {
    return sdf.box(p, v.vec3(0.8, 0.8, 0.8));
}

/// Scene SDF: box on a plane (for testing AO and shadows).
fn sceneBoxOnPlane(p: Vec3) f32 {
    const box_pos = p - v.vec3(0, 0.3, 0);
    const box_dist = sdf.box(box_pos, v.vec3(0.5, 0.5, 0.5));
    const plane_dist = sdf.plane(p, v.vec3(0, 1, 0), 0.8);
    return @min(box_dist, plane_dist);
}

pub fn main() !void {
    const size = terminal.getSize() catch terminal.Size{ .width = 80, .height = 24 };
    const width: usize = size.width;
    const height: usize = size.height;

    const stdout = std.fs.File.stdout();
    var buf: [1 << 16]u8 = undefined;
    var writer = stdout.writer(&buf);
    const out = &writer.interface;

    // Fixed camera setup: eye at z=3 looking toward origin.
    const eye = v.vec3(0, 0, 3.0);
    const fov: f32 = 1.0;
    // Terminal characters are roughly twice as tall as wide.
    const aspect = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height)) * 0.5;

    try terminal.clearScreen(out);

    for (0..height) |row| {
        for (0..width) |col| {
            // Map pixel to normalized screen coords (-1..1).
            const u = (@as(f32, @floatFromInt(col)) / @as(f32, @floatFromInt(width)) * 2.0 - 1.0) * aspect;
            const vv = -(@as(f32, @floatFromInt(row)) / @as(f32, @floatFromInt(height)) * 2.0 - 1.0);

            const dir = v.normalize(v.vec3(u * fov, vv * fov, -1.0));

            if (render.march(eye, dir, sceneSphere)) |hit| {
                const normal = render.estimateNormal(hit.pos, sceneSphere);
                const view_dir = v.normalize(eye - hit.pos);
                const brightness = render.shade(hit.pos, normal, view_dir, sceneSphere);

                const color = terminal.brightnessToColor(brightness);
                try terminal.writeFgColor(out, color);
                try out.writeByte('#');
            } else {
                try out.writeByte(' ');
            }
        }
        try terminal.resetColors(out);
        try out.writeByte('\n');
    }

    try out.flush();
}

test {
    _ = @import("vec3.zig");
    _ = @import("sdf.zig");
    _ = @import("camera.zig");
}
