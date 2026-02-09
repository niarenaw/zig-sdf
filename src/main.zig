const std = @import("std");
const v = @import("vec3.zig");
const Vec3 = v.Vec3;
const sdf = @import("sdf.zig");
const render = @import("render.zig");
const terminal = @import("terminal.zig");
const cam = @import("camera.zig");

const Scene = enum {
    hello,
    blobs,
    difference,
    pillars,
    crystal,
    rings,

    const names = [_][]const u8{ "hello", "blobs", "difference", "pillars", "crystal", "rings" };
    const descriptions = [_][]const u8{
        "smooth sphere with sunset gradient",
        "organic metaballs in warm tones",
        "sphere carved from a box",
        "repeating cylinders on a ground plane",
        "faceted crystal with neon edges",
        "interlocking tori in rainbow",
    };
    const count = @typeInfo(Scene).@"enum".fields.len;

    fn next(self: Scene) Scene {
        return @enumFromInt((@intFromEnum(self) + 1) % count);
    }

    fn name(self: Scene) []const u8 {
        return names[@intFromEnum(self)];
    }

    fn fromName(str: []const u8) ?Scene {
        for (names, 0..) |n, i| {
            if (std.mem.eql(u8, str, n)) return @enumFromInt(i);
        }
        return null;
    }
};

fn renderScene(fb: *terminal.FrameBuffer, scene: Scene, camera: cam.Camera) void {
    switch (scene) {
        .hello => render.renderFrameColor(fb, sdf.scene_hello, sdf.color_hello, camera),
        .blobs => render.renderFrameColor(fb, sdf.scene_blobs, sdf.color_blobs, camera),
        .difference => render.renderFrameColor(fb, sdf.scene_difference, sdf.color_difference, camera),
        .pillars => render.renderFrameColor(fb, sdf.scene_pillars, sdf.color_pillars, camera),
        .crystal => render.renderFrameColor(fb, sdf.scene_crystal, sdf.color_crystal, camera),
        .rings => render.renderFrameColor(fb, sdf.scene_rings, sdf.color_rings, camera),
    }
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const stdout = std.fs.File.stdout();
    var buf: [1 << 18]u8 = undefined;
    var writer = stdout.writer(&buf);
    const out = &writer.interface;

    // Parse CLI arguments.
    var initial_scene: Scene = .hello;
    var args = std.process.args();
    _ = args.skip(); // Skip executable name.
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--list")) {
            try out.writeAll("Available scenes:\n");
            for (Scene.names, Scene.descriptions) |n, desc| {
                var line_buf: [80]u8 = undefined;
                const line = try std.fmt.bufPrint(&line_buf, "  {s:<14} {s}\n", .{ n, desc });
                try out.writeAll(line);
            }
            try out.flush();
            return;
        } else if (std.mem.eql(u8, arg, "--scene")) {
            if (args.next()) |scene_name| {
                if (Scene.fromName(scene_name)) |s| {
                    initial_scene = s;
                } else {
                    try out.writeAll("Unknown scene. Use --list to see available scenes.\n");
                    try out.flush();
                    return;
                }
            }
        }
    }

    const old_termios = terminal.enterRawMode() catch {
        return renderStatic(out, allocator, initial_scene);
    };
    defer terminal.exitRawMode(old_termios);

    try terminal.hideCursor(out);
    defer terminal.showCursor(out) catch {};

    // Startup banner.
    try terminal.clearScreen(out);
    try out.writeAll(
        \\
        \\   ╔══════════════════════════════════╗
        \\   ║          zig-sdf renderer         ║
        \\   ╠══════════════════════════════════╣
        \\   ║  arrows   rotate camera           ║
        \\   ║  +/-      zoom in/out             ║
        \\   ║  tab      cycle scenes            ║
        \\   ║  q        quit                    ║
        \\   ╚══════════════════════════════════╝
        \\
    );
    try out.flush();

    // Brief pause so the user can read the banner.
    std.Thread.sleep(1_500_000_000);

    try terminal.clearScreen(out);
    try out.flush();

    var camera = cam.defaultCamera();
    var current_scene: Scene = initial_scene;

    var size = terminal.getSize() catch terminal.Size{ .width = 80, .height = 24 };
    var fb = try terminal.createFrameBuffer(allocator, size.width, size.height);

    while (true) {
        const new_size = terminal.getSize() catch size;
        if (new_size.width != size.width or new_size.height != size.height) {
            terminal.destroyFrameBuffer(allocator, fb);
            size = new_size;
            fb = try terminal.createFrameBuffer(allocator, size.width, size.height);
            try terminal.clearScreen(out);
            try out.flush();
        }

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

        try terminal.resetColors(out);
        var hud_buf: [128]u8 = undefined;
        const hud = try std.fmt.bufPrint(&hud_buf, " [{s}]  arrows:rotate  +/-:zoom  tab:scene  q:quit", .{current_scene.name()});
        try out.writeAll(hud);

        try out.flush();
    }

    try terminal.clearScreen(out);
    try terminal.showCursor(out);
    try out.flush();
    terminal.destroyFrameBuffer(allocator, fb);
}

fn renderStatic(out: *std.Io.Writer, allocator: std.mem.Allocator, scene: Scene) !void {
    const size = terminal.getSize() catch terminal.Size{ .width = 80, .height = 24 };
    var fb = try terminal.createFrameBuffer(allocator, size.width, size.height);
    defer terminal.destroyFrameBuffer(allocator, fb);

    renderScene(&fb, scene, cam.defaultCamera());

    try terminal.clearScreen(out);
    try terminal.renderHalfBlock(fb, out);
    try out.flush();
}

test {
    _ = @import("vec3.zig");
    _ = @import("sdf.zig");
    _ = @import("camera.zig");
}
