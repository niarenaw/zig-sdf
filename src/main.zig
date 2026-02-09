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

    const eye = v.vec3(0, 0, 3.0);
    const fov: f32 = 1.0;
    // Aspect is based on pixel dimensions: width / (height * 2) since
    // half-block rendering doubles vertical resolution.
    const aspect = @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height * 2));

    var fb = try terminal.createFrameBuffer(std.heap.page_allocator, width, height);
    defer terminal.destroyFrameBuffer(std.heap.page_allocator, fb);

    render.renderFrame(&fb, sceneSphere, eye, fov, aspect);

    try terminal.clearScreen(out);
    try terminal.renderHalfBlock(fb, out);
    try out.flush();
}

test {
    _ = @import("vec3.zig");
    _ = @import("sdf.zig");
    _ = @import("camera.zig");
}
