const std = @import("std");
const vk = @import("vulkan");
const GraphicsContext = @import("vk_graphics_context").GraphicsContext;
const Swapchain = @import("vk_swapchain").Swapchain;
const Allocator = std.mem.Allocator;

pub fn createFramebuffers(gctx: *const GraphicsContext, allocator: Allocator, render_pass: vk.RenderPass, swapchain: Swapchain) ![]vk.Framebuffer {
    const framebuffers = try allocator.alloc(vk.Framebuffer, swapchain.swap_images.len);
    errdefer allocator.free(framebuffers);

    var i: usize = 0;
    errdefer for (framebuffers[0..i]) |fb| gctx.dev.destroyFramebuffer(fb, null);

    for (framebuffers) |*fb| {
        fb.* = try gctx.dev.createFramebuffer(&.{
            .render_pass = render_pass,
            .attachment_count = 1,
            .p_attachments = @ptrCast(&swapchain.swap_images[i].view),
            .width = swapchain.extent.width,
            .height = swapchain.extent.height,
            .layers = 1,
        }, null);
        i += 1;
    }

    return framebuffers;
}

pub fn destroyFramebuffers(gctx: *const GraphicsContext, allocator: Allocator, framebuffers: []const vk.Framebuffer) void {
    for (framebuffers) |fb| gctx.dev.destroyFramebuffer(fb, null);
    allocator.free(framebuffers);
}

