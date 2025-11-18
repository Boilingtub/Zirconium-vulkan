const std = @import("std");
const Zr = @import("Zirconium");
const zwin = Zr.zwin;

const app_name : [:0]const u8 = "Zirconium-Demo : 0.0.1 : triangle";
const wwidth = 1280;
const wheight = 720;

pub fn main() !void {   
    try Zr.print("Zirconium Startup...\n");

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit(); 
    const allocator = gpa.allocator();
    
    zwin.init();
    var window: zwin.Window = zwin.Window.empty();
    window.init(wwidth, wheight, app_name) catch {
            std.debug.print("Error! Could not create zwin window!\n\n", .{});
            unreachable;
    };
    defer window.destroy();
     
    var state = try Zr.gpu.State.create_vulkan_state(
        allocator,                          
        &window,
        app_name,
    );
    defer state.destroy_vulkan_state(allocator);

    //populate State 
        
    //Input Loop
    var frame_count: u32 = 0;
    while (window.running) {
        //std.debug.print("attempting fame render : {d}\n", .{frame_count});
        frame_count += 1;
        if(window.width == 0 or window.height == 0) {
            std.debug.print("invalid surface dimension : w={},h={} skipping...\n", .{
                window.width,window.height
            });
            try window.pollEvents();
            continue;
        }
        try window.pollEvents();
        try Zr.render(allocator, &state, &window);
    }
    
    try state.swapchain.waitForAllFences();
    try state.gctx.dev.deviceWaitIdle();
}

