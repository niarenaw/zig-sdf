const std = @import("std");
const v = @import("vec3.zig");

pub fn main() !void {
    const stdout = std.fs.File.stdout();
    var buf: [4096]u8 = undefined;
    var writer = stdout.writer(&buf);
    const out = &writer.interface;

    const a = v.vec3(1.0, 2.0, 3.0);
    const b = v.vec3(4.0, 5.0, 6.0);
    const n = v.normalize(a);

    try out.print("a         = ({d:.3}, {d:.3}, {d:.3})\n", .{ a[0], a[1], a[2] });
    try out.print("b         = ({d:.3}, {d:.3}, {d:.3})\n", .{ b[0], b[1], b[2] });
    try out.print("a + b     = ({d:.3}, {d:.3}, {d:.3})\n", .{ (a + b)[0], (a + b)[1], (a + b)[2] });
    try out.print("dot(a, b) = {d:.3}\n", .{v.dot(a, b)});
    try out.print("cross     = ({d:.3}, {d:.3}, {d:.3})\n", .{ v.cross(a, b)[0], v.cross(a, b)[1], v.cross(a, b)[2] });
    try out.print("len(a)    = {d:.3}\n", .{v.length(a)});
    try out.print("norm(a)   = ({d:.3}, {d:.3}, {d:.3})\n", .{ n[0], n[1], n[2] });

    try out.flush();
}

test {
    _ = @import("vec3.zig");
}
