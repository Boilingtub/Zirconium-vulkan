const std = @import("std");
const mem = std.mem;
const posix = std.posix;

const wayland = @import("wayland");
const wl = wayland.client.wl;
const xdg = wayland.client.xdg;

const Context = struct {
    shm: ?*wayland.client.wl.Shm,
    compositor: ?*wayland.client.wl.Compositor,
    wm_base: ?*wayland.client.xdg.WmBase,
};

pub const Window = struct {
    running:*bool,
    title:[]const u8,
    width: u16,
    height: u16,
    context: Context,
    WL : struct {
        display: *wl.Display,
        registry: *wl.Registry,
        surface: *wl.Surface,
        xdg_surface: *xdg.Surface,
        xdg_toplevel: *xdg.Toplevel,
        buffer: *wl.Buffer,
    },

    pub fn create(width:u16, height:u16, title:[]const u8) !*Window {
        const display = try wl.Display.connect(null);
        const registry = try display.getRegistry();

        var context = Context{
            .shm = null,
            .compositor = null,
            .wm_base = null,
        };
         
        registry.setListener(*Context, registryListener, &context);
        if (display.roundtrip() != .SUCCESS) return error.RoundtripFailed;

        const shm = context.shm orelse return error.NoWlShm;
        const compositor = context.compositor orelse return error.NoWlCompositor;
        const wm_base = context.wm_base orelse return error.NoXdgWmBase;

        const buffer = blk: {
            const stride:u32 = width * 4;
            const size:u32 = stride * height;
             
            const fd = try posix.memfd_create(title, 0);
            try posix.ftruncate(fd, @intCast(size));
            //const data = try posix.mmap(
            //    null,
            //    size,
            //    posix.PROT.READ | posix.PROT.WRITE,
            //    .{ .TYPE = .SHARED },
            //    fd,
            //    0,
            //);
            //@memcpy(data, @embedFile("cat.bgra"));
            
            const pool = try shm.createPool(fd, @intCast(size));
            defer pool.destroy();
            
            break :blk try pool.createBuffer(0, width, height, @intCast(stride), wl.Shm.Format.argb8888);
        };
        const surface = try compositor.createSurface();
        const xdg_surface = try wm_base.getXdgSurface(surface);
        const xdg_toplevel = try xdg_surface.getToplevel();

        var running = true;

        xdg_surface.setListener(*wl.Surface, xdgSurfaceListener, surface);
        xdg_toplevel.setListener(*bool, xdgToplevelListener, &running);

        surface.commit();
        if (display.roundtrip() != .SUCCESS) return error.RoundtripFailed;

        surface.attach(buffer, 0, 0);
        surface.commit();
        var window: Window = undefined;
        window = .{
            .running = &running,
            .title = title,
            .width = width,
            .height = height,
            .context = context,
            .WL = .{
                .display = display,
                .registry = registry,
                .surface = surface,
                .xdg_surface = xdg_surface,
                .xdg_toplevel = xdg_toplevel,
                .buffer = buffer,


            },
        };
        return &window;
    }   

    pub fn destroy(self: *Window) void {
        self.WL.buffer.destroy();
        self.WL.surface.destroy();
        self.WL.xdg_surface.destroy();
        self.WL.xdg_toplevel.destroy();
    }

    pub fn Dispatch(self: *Window) !void {
            if (self.WL.display.dispatch() != .SUCCESS) return error.DispatchFailed;
    }


};


fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, context: *Context) void {
    switch (event) {
        .global => |global| {
            if (mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                context.compositor = registry.bind(global.name, wl.Compositor, 1) catch return;
            } else if (mem.orderZ(u8, global.interface, wl.Shm.interface.name) == .eq) {
                context.shm = registry.bind(global.name, wl.Shm, 1) catch return;
            } else if (mem.orderZ(u8, global.interface, xdg.WmBase.interface.name) == .eq) {
                context.wm_base = registry.bind(global.name, xdg.WmBase, 1) catch return;
            }
        },
        .global_remove => {},
    }
}

fn xdgSurfaceListener(xdg_surface: *xdg.Surface, event: xdg.Surface.Event, surface: *wl.Surface) void {
    switch (event) {
        .configure => |configure| {
            xdg_surface.ackConfigure(configure.serial);
            surface.commit();
        },
    }
}

fn xdgToplevelListener(_: *xdg.Toplevel, event: xdg.Toplevel.Event, running: *bool) void {
    switch (event) {
        .configure => {},
        .close => running.* = false,
    }
}

pub fn isVulkanSupported() bool {
    return true;
}

pub fn getRequiredInstanceExtensions() ![]const []const u8 {
   std.debug.print("zwin.getRequiredInstanceExtensions is not implemented", .{});
   const strings = [_][]const u8{
       "zwin.getRequiredInstanceExtensions not implemented",
       "Please revisit"
   };
   return &strings;
}

pub fn getInstanceProcAddress() void {
       const lib = std.DynLib.open("libvulkan") catch unreachable; 
        
}
