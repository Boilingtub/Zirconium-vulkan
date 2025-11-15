const std = @import("std");
pub const gpu = @import("gpu");
pub const zwin = @import("zwin");

pub fn render(
    allocator: std.mem.Allocator, 
    state: *gpu.State,
    window :*zwin.Window) !void {

    const w = window.width;
    const h = window.height;

    if((state.present_state == .suboptimal or
    state.extent.width != @as(u32,@intCast(w)) or
    state.extent.height != @as(u32,@intCast(h))) and window.needs_resize)  {
        std.debug.print("🔄 Resizing from {}x{} to {}x{}\n",
            .{state.extent.width, state.extent.height, w, h});
        //try state.gctx.dev.deviceWaitIdle();

        state.extent.width = @as(u32,@intCast(w));
        state.extent.height = @as(u32,@intCast(h));
        try state.swapchain.recreate(state.extent);

        gpu.destroyFramebuffers(state.gctx, allocator, state.framebuffers);
        state.framebuffers = try gpu.createFramebuffers(
            state.gctx, allocator, state.render_pass, state.swapchain
        );

        gpu.destroyCommandBuffers(state.gctx, state.pool, allocator, state.cmdbufs);
        state.cmdbufs = try gpu.createCommandBuffers(
            state.gctx,
            gpu.vertices.len,
            state.pool,
            allocator,
            state.buffer,
            state.swapchain.extent,
            state.render_pass,
            state.pipeline,
            state.framebuffers,
        );
        window.needs_resize = false;
    }

    const cmdbuf = state.cmdbufs[state.swapchain.image_index];

    state.present_state = state.swapchain.present(cmdbuf) catch |err| switch (err) {
        error.OutOfDateKHR => gpu.Swapchain.PresentState.suboptimal,
        else => |narrow| return narrow,
    };
    window.commit();
}

pub fn print(content: []const u8) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("{s}",.{content});
    try stdout.flush();
}
