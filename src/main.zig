const std = @import("std");
const v = @import("vec3.zig");
const Vec3 = v.Vec3;
const sdf = @import("sdf.zig");
const render = @import("render.zig");
const terminal = @import("terminal.zig");
const cam = @import("camera.zig");

const Scene = enum {
    blobs,
    difference,
    pillars,

    const names = [_][]const u8{ "blobs", "difference", "pillars" };
    const count = @typeInfo(Scene).@"enum".fields.len;

    fn next(self: Scene) Scene {
        const idx = (@intFromEnum(self) + 1) % count;
        return @enumFromInt(idx);
    }

    fn name(self: Scene) []const u8 {
        return names[@intFromEnum(self)];
    }
};

fn renderScene(fb: *terminal.FrameBuffer, scene: Scene, camera: cam.Camera) void {
    switch (scene) {
        .blobs => render.renderFrame(fb, sdf.scene_blobs, camera),
        .difference => render.renderFrame(fb, sdf.scene_difference, camera),
        .pillars => render.renderFrame(fb, sdf.scene_pillars, camera),
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const stdout = std.fs.File.stdout();
    var buf: [1 << 18]u8 = undefined;
    var writer = stdout.writer(&buf);
    const out = &writer.interface;

    const old_termios = terminal.enterRawMode() catch {
        // Fallback: render one frame without interactivity.
        return renderStatic(out, allocator);
    };
    defer terminal.exitRawMode(old_termios);

    try terminal.hideCursor(out);
    defer terminal.showCursor(out) catch {};
    try terminal.clearScreen(out);
    try out.flush();

    var camera = cam.defaultCamera();
    var current_scene: Scene = .blobs;

    var size = terminal.getSize() catch terminal.Size{ .width = 80, .height = 24 };
    var fb = try terminal.createFrameBuffer(allocator, size.width, size.height);

    while (true) {
        // Re-check terminal size and reallocate if needed.
        const new_size = terminal.getSize() catch size;
        if (new_size.width != size.width or new_size.height != size.height) {
            terminal.destroyFrameBuffer(allocator, fb);
            size = new_size;
            fb = try terminal.createFrameBuffer(allocator, size.width, size.height);
            try terminal.clearScreen(out);
            try out.flush();
        }

        // Poll for input (~60fps target).
        if (terminal.pollKey(16)) |key| {
            switch (key) {
                .q => break,
                .left => camera.yaw -= 0.1,
                .right => camera.yaw += 0.1,
                .up => camera.pitch = @min(camera.pitch + 0.1, std.math.pi / 2.0 - 0.01),
                .down => camera.pitch = @max(camera.pitch - 0.1, -std.math.pi / 2.0 + 0.01),
                .plus => camera.distance = @max(1.0, camera.distance - 0.2),
                .minus => camera.distance += 0.2,
                .tab => current_scene = current_scene.next(),
                .other => {},
            }
        }

        terminal.clearFrameBuffer(&fb);
        renderScene(&fb, current_scene, camera);

        try terminal.cursorHome(out);
        try terminal.renderHalfBlock(fb, out);

        // HUD: scene name and controls on the last line.
        try terminal.resetColors(out);
        var hud_buf: [128]u8 = undefined;
        const hud = try std.fmt.bufPrint(&hud_buf, " [{s}]  arrows:rotate  +/-:zoom  tab:scene  q:quit", .{current_scene.name()});
        try out.writeAll(hud);

        try out.flush();
    }

    // Clean exit: clear screen, restore terminal.
    try terminal.clearScreen(out);
    try terminal.showCursor(out);
    try out.flush();
    terminal.destroyFrameBuffer(allocator, fb);
}

/// Render a single static frame when raw mode is unavailable.
fn renderStatic(out: *std.Io.Writer, allocator: std.mem.Allocator) !void {
    const size = terminal.getSize() catch terminal.Size{ .width = 80, .height = 24 };
    var fb = try terminal.createFrameBuffer(allocator, size.width, size.height);
    defer terminal.destroyFrameBuffer(allocator, fb);

    render.renderFrame(&fb, sdf.scene_blobs, cam.defaultCamera());

    try terminal.clearScreen(out);
    try terminal.renderHalfBlock(fb, out);
    try out.flush();
}

test {
    _ = @import("vec3.zig");
    _ = @import("sdf.zig");
    _ = @import("camera.zig");
}
