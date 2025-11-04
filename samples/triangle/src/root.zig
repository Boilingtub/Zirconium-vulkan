const std = @import("std");
pub const gpu = @import("gpu");
pub const glfw = @import("zglfw");

pub fn render(
    allocator: std.mem.Allocator, 
    state: *gpu.State,
    w: c_int, h:c_int) !void {


    const cmdbuf = state.cmdbufs[state.swapchain.image_index];

    if(state.present_state == .suboptimal or
       state.extent.width != @as(u32,@intCast(w)) or
       state.extent.height != @as(u32,@intCast(h))) {
        state.extent.width = @as(u32,@intCast(w));
        state.extent.height = @as(u32,@intCast(h));
        try state.swapchain.recreate(state.extent);

        gpu.destroyFramebuffers(&state.gctx, allocator, state.framebuffers);
        state.framebuffers = try gpu.createFramebuffers(
            &state.gctx, allocator, state.render_pass, state.swapchain
        );

        gpu.destroyCommandBuffers(&state.gctx, state.pool, allocator, state.cmdbufs);
        state.cmdbufs = try gpu.createCommandBuffers(
            &state.gctx,
            gpu.vertices.len,
            state.pool,
            allocator,
            state.buffer,
            state.swapchain.extent,
            state.render_pass,
            state.pipeline,
            state.framebuffers,
        );
    }
    state.present_state = state.swapchain.present(cmdbuf) catch |err| switch (err) {
        error.OutOfDateKHR => gpu.Swapchain.PresentState.suboptimal,
        else => |narrow| return narrow,
    };
    glfw.pollEvents();
}

pub const Windowing = struct {
    pub const CURSOR = glfw.InputMode.cursor;
    pub const CURSOR_NORMAL = glfw.InputMode.cursor.ValueType().normal;
    pub const CURSOR_HIDDEN = glfw.InputMode.cursor.ValueType().hidden;
    pub const CURSOR_DISABLED = glfw.InputMode.cursor.ValueType().disabled;
    pub const CURSOR_CAPTURED = glfw.InputMode.cursor.ValueType().captured;

    pub fn init() void {
        glfw.init() catch {
            std.debug.print("Error! failed to initialize zglfw for windowing!\n\n", .{});
            unreachable;
        };
        glfw.windowHint(.client_api, .no_api);
    }
    pub fn create_window(width: u16, height: u16, title: [:0]const u8) *glfw.Window {
        const window = glfw.Window.create(width, height, title, null) catch {
            std.debug.print("Error! Could not create zglfw window!\n\n", .{});
            unreachable;
        };
        return window;
    }
    pub fn terminate() void {
        glfw.terminate();
    }
    pub fn pollEvents() void {
        glfw.pollEvents();
    }
    pub fn setCursorPos(window:*glfw.Window,x:f64,y:f64) void {
        glfw.setCursorPos(window,x,y);      
    }
    pub fn setInputMode(window:*glfw.Window,mode:u32,mode_value:u32) void {
        glfw.setInputMode(window,mode,mode_value);      
    }
};

pub fn print(content: []const u8) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("{s}",.{content});
    try stdout.flush();
}
