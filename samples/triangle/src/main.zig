const std = @import("std");
const Zr = @import("Zirconium");
const glfw = Zr.glfw;

const app_name : [:0]const u8 = "Zirconium-Demo : 0.0.1 : triangle";
const wwidth = 1280;
const wheight = 720;

pub fn main() !void {
    try Zr.print("Zirconium Startup...\n");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit(); 
    const allocator = gpa.allocator();
    
    glfw.init() catch {
            std.debug.print("Error! failed to initialize zglfw for windowing!\n\n", .{});
            unreachable;
        };
    glfw.windowHint(.client_api, .no_api);

    defer glfw.terminate();

    const window = glfw.Window.create(wwidth, wheight, app_name, null) catch {
            std.debug.print("Error! Could not create zglfw window!\n\n", .{});
            unreachable;
        };

    defer window.destroy();
    try window.setInputMode(
        glfw.InputMode.cursor,
        glfw.InputMode.cursor.ValueType().disabled
    );
     
    var state = try Zr.gpu.State.create_vulkan_state(
        allocator, 
        window,
        app_name,
    );
    defer state.destroy_vulkan_state(allocator);

    //populate State 
        
    //Input Loop
    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        var w: c_int = undefined;
        var h: c_int = undefined;
        glfw.getFramebufferSize(window, &w, &h);
        if (w == 0 or h == 0) {
            glfw.pollEvents();
            continue;
        }
        try Zr.render(allocator, &state, w, h);
        //state.draw_render();
    }
    
    try state.swapchain.waitForAllFences();
    try state.gctx.dev.deviceWaitIdle();
}

