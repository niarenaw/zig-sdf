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
