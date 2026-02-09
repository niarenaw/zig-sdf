const std = @import("std");
const v = @import("vec3.zig");
const Vec3 = v.Vec3;

pub const Size = struct {
    width: u16,
    height: u16,
};

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

/// Query terminal dimensions via TIOCGWINSZ ioctl.
pub fn getSize() !Size {
    var ws: std.posix.winsize = .{ .row = 0, .col = 0, .xpixel = 0, .ypixel = 0 };
    const fd = std.fs.File.stdout().handle;
    const rc = std.posix.system.ioctl(fd, std.posix.T.IOCGWINSZ, @intFromPtr(&ws));
    if (std.posix.errno(rc) != .SUCCESS) return error.IoctlFailed;
    if (ws.col == 0 or ws.row == 0) return error.InvalidSize;
    return .{ .width = ws.col, .height = ws.row };
}

/// ASCII brightness ramp from dark to light.
const brightness_ramp = " .:-=+*#%@";

/// Map a 0..1 brightness value to an ASCII character.
pub fn brightnessChar(t: f32) u8 {
    const clamped = @max(0.0, @min(1.0, t));
    const idx: usize = @intFromFloat(clamped * @as(f32, @floatFromInt(brightness_ramp.len - 1)));
    return brightness_ramp[idx];
}

/// Convert brightness (0..1) to a warm orange gradient color.
pub fn brightnessToColor(brightness: f32) Color {
    const clamped = @max(0.0, @min(1.0, brightness));

    // Warm orange gradient: dark brown -> orange -> bright yellow-white.
    const r = @as(u8, @intFromFloat(20.0 + clamped * 235.0));
    const g = @as(u8, @intFromFloat(10.0 + clamped * 180.0));
    const b = @as(u8, @intFromFloat(5.0 + clamped * 80.0));

    return .{ .r = r, .g = g, .b = b };
}

/// Write truecolor ANSI escape sequence for foreground color.
pub fn writeFgColor(writer: *std.Io.Writer, color: Color) !void {
    var buf: [32]u8 = undefined;
    const seq = try std.fmt.bufPrint(&buf, "\x1b[38;2;{d};{d};{d}m", .{ color.r, color.g, color.b });
    try writer.writeAll(seq);
}

/// Write truecolor ANSI escape sequence for background color.
pub fn writeBgColor(writer: *std.Io.Writer, color: Color) !void {
    var buf: [32]u8 = undefined;
    const seq = try std.fmt.bufPrint(&buf, "\x1b[48;2;{d};{d};{d}m", .{ color.r, color.g, color.b });
    try writer.writeAll(seq);
}

/// Reset terminal colors to default.
pub fn resetColors(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b[0m");
}

/// Clear the screen and move cursor to home position.
pub fn clearScreen(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b[2J\x1b[H");
}

// ── FrameBuffer ────────────────────────────────────────────────────────

pub const FrameBuffer = struct {
    pixels: []Color,
    width: usize,
    pixel_height: usize,
};

const bg_black = Color{ .r = 0, .g = 0, .b = 0 };

pub fn createFrameBuffer(allocator: std.mem.Allocator, width: usize, term_height: usize) !FrameBuffer {
    const pixel_height = term_height * 2;
    const pixels = try allocator.alloc(Color, width * pixel_height);
    @memset(pixels, bg_black);
    return .{ .pixels = pixels, .width = width, .pixel_height = pixel_height };
}

pub fn destroyFrameBuffer(allocator: std.mem.Allocator, fb: FrameBuffer) void {
    allocator.free(fb.pixels);
}

pub fn setPixel(fb: *FrameBuffer, x: usize, y: usize, color: Color) void {
    fb.pixels[y * fb.width + x] = color;
}

pub fn getPixel(fb: FrameBuffer, x: usize, y: usize) Color {
    return fb.pixels[y * fb.width + x];
}

/// Render the framebuffer using half-block characters. Each terminal row
/// encodes two pixel rows: the top pixel as the foreground color and the
/// bottom pixel as the background color of the `▀` character.
pub fn renderHalfBlock(fb: FrameBuffer, writer: *std.Io.Writer) !void {
    var y: usize = 0;
    while (y < fb.pixel_height) : (y += 2) {
        const has_bottom = (y + 1) < fb.pixel_height;
        for (0..fb.width) |x| {
            const top = getPixel(fb, x, y);
            const bot = if (has_bottom) getPixel(fb, x, y + 1) else bg_black;

            try writeFgBgColor(writer, top, bot);
            try writer.writeAll("▀");
        }
        try resetColors(writer);
        try writer.writeByte('\n');
    }
}

/// Write combined fg + bg truecolor escape in a single sequence.
fn writeFgBgColor(writer: *std.Io.Writer, fg: Color, bg: Color) !void {
    var buf: [64]u8 = undefined;
    const seq = try std.fmt.bufPrint(&buf, "\x1b[38;2;{d};{d};{d};48;2;{d};{d};{d}m", .{
        fg.r, fg.g, fg.b,
        bg.r, bg.g, bg.b,
    });
    try writer.writeAll(seq);
}
