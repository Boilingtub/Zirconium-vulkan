const std = @import("std");
const vk = @import("vulkan");
const glfw = @import("zglfw");

pub fn print(content: []const u8) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("{s}",.{content});
    try stdout.flush();
}

pub fn init() !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.createWindow(
        1080, 720, "Zirconium", null,
    );
    
    defer glfw.destroyWindow(window);
}
