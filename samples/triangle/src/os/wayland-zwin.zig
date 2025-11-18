const std = @import("std");
const mem = std.mem;
const posix = std.posix;

const wayland = @import("wayland");
const wl = wayland.client.wl;
const xdg = wayland.client.xdg;

pub const BACKEND_TYPE = enum {
    Vulkan,
    OpenGL,
    None,
};
pub var backend:BACKEND_TYPE = BACKEND_TYPE.None;
pub var zwinVkgetInstanceProcAddr: *anyopaque = undefined;
var found_vulkan:bool = false;

var reqVkExtensions = .{
    "VK_KHR_surface",
    "VK_KHR_wayland_surface",
};

pub fn init() void {
    zwinVkgetInstanceProcAddr = getInstanceProcAddr() catch |e| {
        std.log.err("zwin.init() returned error {}\n",.{e});
        std.process.exit(1);
    };
    std.debug.print("zwin init() successfull !\n", .{});
}

const Context = struct {
    compositor: ?*wayland.client.wl.Compositor,
    wm_base: ?*wayland.client.xdg.WmBase,
};

pub const Window = struct {
    running:bool,
    title:[*:0]const u8,
    width: u16,
    height: u16,
    needs_resize: bool,
    WL : struct {
        context: Context,
        display: *wl.Display,
        registry: *wl.Registry,
        surface: *wl.Surface,
        xdg_surface: *xdg.Surface,
        xdg_toplevel: *xdg.Toplevel,
    },

    pub fn empty() Window {
        const window : Window = .{
            .running = false,
            .title = "",
            .width = 0,
            .height = 0,
            .needs_resize = false,
            .WL = .{
                .context = Context{.wm_base = null, .compositor = null},
                .display = undefined,
                .registry = undefined,
                .surface = undefined,
                .xdg_surface = undefined,
                .xdg_toplevel = undefined,
            }
        };
        return window;
    }

    pub fn init(window: *Window, width:u16, height:u16, title:[*:0]const u8) !void {
        window.WL.display = try wl.Display.connect(null);
        const registry = try window.WL.display.getRegistry();
        window.running = true;
        window.title = title;
        window.width = width;
        window.height = height;
        window.needs_resize = false;
        window.WL.context = Context{.wm_base = null, .compositor = null};

        registry.setListener(*Context, registryListener, &window.WL.context);
        if (window.WL.display.roundtrip() != .SUCCESS) return error.RoundtripFailed;

        const compositor = window.WL.context.compositor orelse return error.NoWlCompositor;
        const wm_base = window.WL.context.wm_base orelse return error.NoXdgWmBase;
        wm_base.setListener(*Window, xdgWmBaseListner, window);
        window.WL.surface = try compositor.createSurface();
        window.WL.xdg_surface = try wm_base.getXdgSurface(window.WL.surface);
        window.WL.xdg_surface.setListener(*Window, xdgSurfaceListener, window);
        window.WL.xdg_toplevel = try window.WL.xdg_surface.getToplevel();
        window.WL.xdg_toplevel.setListener(*Window, xdgToplevelListener, window);
        window.WL.xdg_toplevel.setAppId(title);
        window.WL.xdg_toplevel.setTitle(title);


        window.WL.surface.commit();

        var timeout_count:u8 = 0;
        while (window.needs_resize and timeout_count < 100) {

            if (window.WL.display.roundtrip() != .SUCCESS) return error.RoundtripFailed;

            timeout_count += 1;
        }

        std.debug.print("window {s} initialized successfully !\n", .{title});
    }   

    pub fn destroy(self: *Window) void {
        self.WL.xdg_toplevel.destroy();
        self.WL.xdg_surface.destroy();
        self.WL.surface.destroy();
        if(self.WL.context.wm_base) |wm_base| {
            wm_base.destroy();
        }
        if(self.WL.context.compositor) |compositor| {
            compositor.destroy();
        }
        self.WL.registry.destroy();
        self.WL.display.disconnect();
    }

    pub fn Dispatch(self: *Window) !void {
        if (self.WL.display.dispatch() != .SUCCESS) return error.DispatchFailed;
    }

    pub fn pollEvents(self: *Window) !void {
        if (self.WL.display.roundtrip() != .SUCCESS) return error.RoundtripFailed;
    }

    pub fn commit(self:*Window) void {
        self.WL.surface.commit();
    }

};

fn registryListener(registry: *wl.Registry, event: wl.Registry.Event, context: *Context) void {
    switch (event) {
        .global => |global| {
            if (mem.orderZ(u8, global.interface, wl.Compositor.interface.name) == .eq) {
                context.compositor = registry.bind(global.name, wl.Compositor, 1)
                    catch return;
            } else 
            if (mem.orderZ(u8, global.interface, xdg.WmBase.interface.name) == .eq) {
                context.wm_base = registry.bind(global.name, xdg.WmBase, 1) catch return;
            }
        },
        .global_remove => |global_remove| {
            if(context.compositor != null and
                context.compositor.?.getId() == global_remove.name) {
                context.compositor = null;
            } else if (context.wm_base != null and
                context.wm_base.?.getId() == global_remove.name) {
                context.wm_base = null;
            }
        },
    }
}

fn xdgWmBaseListner(_: *xdg.WmBase, event: xdg.WmBase.Event, window: *Window) void {
    switch (event) {
        .ping => |ping| {
            window.WL.context.wm_base.?.*.pong(ping.serial);
        }
    }
}

fn xdgSurfaceListener(_: *xdg.Surface, event: xdg.Surface.Event, window: *Window) void {
    switch (event) {
        .configure => |configure| {
            window.WL.xdg_surface.ackConfigure(configure.serial);
        },
    }
}

fn xdgToplevelListener(_: *xdg.Toplevel, event: xdg.Toplevel.Event, window: *Window) void {
    switch (event) {
        .configure => |configure| {
            if(configure.width > 0 and configure.height > 0) {
                window.width = @intCast(configure.width);
                window.height = @intCast(configure.height);
                //std.debug.print("Window configured: {}x{}\n", .{window.width, window.height});
                window.needs_resize = true;
            }
        },   
        .close => window.running = false,
    }
}

pub fn isVulkanSupported() bool {
    return found_vulkan;
}

                                        
fn getInstanceProcAddr() !*anyopaque {
    const lib_name = "libvulkan.so";
    var libvk = std.DynLib.open(lib_name) catch |e| {
        std.log.err("ERROR loading {s} {}\n", .{lib_name,e});
        found_vulkan = false;
        return error.NoVulkan;
    };
    found_vulkan = true;
    return libvk.lookup(*anyopaque, "vkGetInstanceProcAddr") orelse {
         std.log.err("found libvulkan.so ! But could not find function \"vkCreateInstance\"\n", .{});
        found_vulkan = false;
        return error.NoVulkanCreateInstanceFunction;
    };
}


pub fn getRequiredInstanceExtensions() []const [*:0]const u8 {
    return &reqVkExtensions;
}
