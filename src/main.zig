const std = @import("std");
const v = @import("vec3.zig");
const Vec3 = v.Vec3;
const sdf = @import("sdf.zig");
const render = @import("render.zig");
const terminal = @import("terminal.zig");

/// Active scene — swap to `sdf.scene_difference` or `sdf.scene_pillars`
/// for a different look.
const scene = sdf.scene_blobs;

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

    render.renderFrame(&fb, scene, eye, fov, aspect);

    try terminal.clearScreen(out);
    try terminal.renderHalfBlock(fb, out);
    try out.flush();
}

test {
    _ = @import("vec3.zig");
    _ = @import("sdf.zig");
    _ = @import("camera.zig");
}
