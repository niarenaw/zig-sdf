const std = @import("std");

pub const Size = struct {
    width: u16,
    height: u16,
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

/// Clear the screen and move cursor to home position.
pub fn clearScreen(writer: *std.Io.Writer) !void {
    try writer.writeAll("\x1b[2J\x1b[H");
}
