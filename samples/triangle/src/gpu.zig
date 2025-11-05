const std = @import("std")  ;
const glfw = @import("zglfw");
//vulkan imports
pub const vk = @import("vulkan");
pub const GraphicsContext = @import("vk_graphics_context").GraphicsContext;
pub const Swapchain = @import("vk_swapchain").Swapchain;
pub const createPipeline = @import("vk_pipeline").createPipeline;
pub const createRenderPass = @import("vk_render_pass").createRenderPass;
pub const createCommandBuffers = @import("vk_command_buffer").createCommandBuffers;
pub const destroyCommandBuffers = @import("vk_command_buffer").destroyCommandBuffers;
pub const createFramebuffers = @import("vk_frame_buffer").createFramebuffers;
pub const destroyFramebuffers = @import("vk_frame_buffer").destroyFramebuffers;
//general_Definitions;
const Allocator = std.mem.Allocator;

// Vulkan Rendering Definitions
pub const vert_spv align(@alignOf(u32)) = @embedFile("vertex_shader").*;
pub const frag_spv align(@alignOf(u32)) = @embedFile("fragment_shader").*;

pub const Vertex = struct {
    pub const binding_description = vk.VertexInputBindingDescription{
        .binding = 0,
        .stride = @sizeOf(Vertex),
        .input_rate = .vertex,
    };

    pub const attribute_description = [_]vk.VertexInputAttributeDescription{
        .{
            .binding = 0,
            .location = 0,
            .format = .r32g32_sfloat,
            .offset = @offsetOf(Vertex, "pos"),
        },
        .{
            .binding = 0,
            .location = 1,
            .format = .r32g32b32_sfloat,
            .offset = @offsetOf(Vertex, "color"),
        },
    };

    pos: [2]f32,
    color: [3]f32,
};

pub const vertices = [_]Vertex{
    .{ .pos = .{ 0, -0.5 }, .color = .{ 1, 0, 0 } },
    .{ .pos = .{ 0.5, 0.5 }, .color = .{ 0, 1, 0 } },
    .{ .pos = .{ -0.5, 0.5 }, .color = .{ 0, 0, 1 } },
};

pub const State = struct {
    gctx : GraphicsContext,
    extent : vk.Extent2D,
    swapchain: Swapchain,
    pipeline_layout: vk.PipelineLayout,
    render_pass: vk.RenderPass,
    pipeline: vk.Pipeline,
    framebuffers : []vk.Framebuffer,
    pool : vk.CommandPool,
    buffer : vk.Buffer,
    memory : vk.DeviceMemory, 
    cmdbufs : []vk.CommandBuffer,
    present_state : Swapchain.PresentState,

    pub fn create_vulkan_state(
        allocator: std.mem.Allocator,
        window : *glfw.Window,
        app_name : [:0]const u8) !State {

        const extent = blk: {
            var w: c_int = undefined;
            var h: c_int = undefined;
            glfw.getFramebufferSize(window, &w, &h);
            break :blk vk.Extent2D{.width = @intCast(w), .height = @intCast(h)};
        };
    
        const gctx = try GraphicsContext.init(allocator, app_name.ptr, window);
        errdefer gctx.deinit();

        std.log.debug("Using device: {s}", .{gctx.deviceName()});

        const swapchain = try Swapchain.init(&gctx, allocator, extent);
        errdefer swapchain.deinit();

        const pipeline_layout = try gctx.dev.createPipelineLayout(&.{
            .flags = .{},
            .set_layout_count = 0,
            .p_set_layouts = undefined,
            .push_constant_range_count = 0,
            .p_push_constant_ranges = undefined,
        }, null);
        errdefer gctx.dev.destroyPipelineLayout(pipeline_layout, null);


        const render_pass = try createRenderPass(&gctx, swapchain);
        errdefer gctx.dev.destroyRenderPass(render_pass,null);

        const pipeline = try createPipeline(
            &gctx, pipeline_layout, render_pass, @ptrCast(&vert_spv), @ptrCast(&frag_spv)
        );
        errdefer gctx.dev.destroyPipeline(pipeline,null);

        const framebuffers = try createFramebuffers(&gctx,
            allocator, render_pass, swapchain);
        errdefer destroyFramebuffers(&gctx,allocator, framebuffers);

        const pool = try gctx.dev.createCommandPool(&.{
                .queue_family_index = gctx.graphics_queue.family, 
            }, null);
        errdefer gctx.dev.destroyCommandPool(pool, null);

        const buffer = try gctx.dev.createBuffer(&.{
            .size = @sizeOf(@TypeOf(vertices)),
            .usage = .{ .transfer_dst_bit = true, .vertex_buffer_bit = true },
            .sharing_mode = .exclusive,
        }, null);
        errdefer gctx.dev.destroyBuffer(buffer, null);


        const mem_reqs = gctx.dev.getBufferMemoryRequirements(buffer);
        const memory = try gctx.allocate(mem_reqs, .{.device_local_bit = true});
        errdefer gctx.dev.freeMemory(memory, null);
        
        try gctx.dev.bindBufferMemory(buffer, memory, 0);

        try uploadVertices(&gctx, pool, buffer);

        const cmdbufs = try createCommandBuffers(
            &gctx,
            vertices.len,
            pool,
            allocator,
            buffer,
            swapchain.extent,
            render_pass,
            pipeline,
            framebuffers,
        );
        errdefer destroyCommandBuffers(&gctx, pool, allocator, cmdbufs);
        
        const present_state: Swapchain.PresentState = .optimal;

        if(glfw.isVulkanSupported()) {
            std.log.err("GLFW could not find libvulkan", .{});
            return error.NoVulkan;
        }


        return .{
            .gctx = gctx,
            .extent = extent,
            .swapchain = swapchain,
            .pipeline_layout = pipeline_layout,
            .render_pass = render_pass,
            .pipeline = pipeline,
            .framebuffers = framebuffers,
            .pool = pool,
            .buffer = buffer,
            .memory = memory, 
            .cmdbufs = cmdbufs,
            .present_state = present_state,

        };
    }

    pub fn destroy_vulkan_state(self: *State, allocator: Allocator) void {

        
        self.gctx.dev.destroyRenderPass(self.render_pass, null);

        self.gctx.dev.destroyPipeline(self.pipeline, null);

        self.gctx.dev.destroyPipelineLayout(self.pipeline_layout, null);

        destroyFramebuffers(
            &self.gctx, allocator, self.framebuffers
        );

        self.gctx.dev.destroyCommandPool(self.pool, null);

        self.gctx.dev.destroyBuffer(self.buffer, null);

        self.gctx.dev.freeMemory(self.memory, null);

        destroyCommandBuffers(
            &self.gctx, self.pool, allocator, self.cmdbufs
        );

        self.gctx.dev.destroyDevice(null);
    }
};

//vulkan Rendering Functions
fn uploadVertices(gctx: *const GraphicsContext, pool: vk.CommandPool, buffer: vk.Buffer) !void {
    const staging_buffer = try gctx.dev.createBuffer(&.{
        .size = @sizeOf(@TypeOf(vertices)),
        .usage = .{ .transfer_src_bit = true },
        .sharing_mode = .exclusive,
    }, null);
defer gctx.dev.destroyBuffer(staging_buffer, null);
    const mem_reqs = gctx.dev.getBufferMemoryRequirements(staging_buffer);
    const staging_memory = try gctx.allocate(mem_reqs, .{ .host_visible_bit = true, .host_coherent_bit = true });
    defer gctx.dev.freeMemory(staging_memory, null);
try gctx.dev.bindBufferMemory(staging_buffer, staging_memory, 0);

    {
        const data = try gctx.dev.mapMemory(staging_memory, 0, vk.WHOLE_SIZE, .{});
defer gctx.dev.unmapMemory(staging_memory);
        
        const gpu_vertices: [*]Vertex = @ptrCast(@alignCast(data));
        @memcpy(gpu_vertices, vertices[0..]);
    }

    try copyBuffer(gctx, pool, buffer, staging_buffer, @sizeOf(@TypeOf(vertices)));
}

fn copyBuffer(gctx: *const GraphicsContext, pool: vk.CommandPool, dst: vk.Buffer, src: vk.Buffer, size: vk.DeviceSize) !void {
    var cmdbuf_handle: vk.CommandBuffer = undefined;
    try gctx.dev.allocateCommandBuffers(&.{
        .command_pool = pool,
        .level = .primary,
        .command_buffer_count = 1,
    }, @ptrCast(&cmdbuf_handle));
    defer gctx.dev.freeCommandBuffers(pool, 1, @ptrCast(&cmdbuf_handle));

    const cmdbuf = GraphicsContext.CommandBuffer.init(cmdbuf_handle, gctx.dev.wrapper);

    try cmdbuf.beginCommandBuffer(&.{
        .flags = .{ .one_time_submit_bit = true },
    });

    const region = vk.BufferCopy{
        .src_offset = 0,
        .dst_offset = 0,
        .size = size,
    };
    cmdbuf.copyBuffer(src, dst, 1, @ptrCast(&region));

    try cmdbuf.endCommandBuffer();

    const si = vk.SubmitInfo{
        .command_buffer_count = 1,
        .p_command_buffers = (&cmdbuf.handle)[0..1],
        .p_wait_dst_stage_mask = undefined,
    };
    try gctx.dev.queueSubmit(gctx.graphics_queue.handle, 1, @ptrCast(&si), .null_handle);
    try gctx.dev.queueWaitIdle(gctx.graphics_queue.handle);
}





