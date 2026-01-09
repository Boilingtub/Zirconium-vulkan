const std = @import("std");
const vkgen = @import("vulkan_zig");

pub fn build(b: *std.Build,
             target:anytype,
             optimize:anytype)
*std.Build.Step.Compile {
    const cwd_path = "samples/triangle";
    const src_path = cwd_path ++ "/src/";
    const content_dir = "/content";
    const use_zig_shaders = b.option(bool, "zig-shader", "Use Zig shaders instead of GLSL") orelse false;

    //create library
    const lib_mod = b.addModule("Zirconium", .{
        .root_source_file = b.path(src_path ++ "root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    }); 

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "Zirconium",
        .root_module = lib_mod,
    });
    //Create exe binary
    const exe = b.addExecutable(.{
        .name = "zirconium-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path(src_path ++ "main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "Zirconium", .module = lib_mod },
            },
        }),
    });

    
    //Modules
    const gpu = b.addModule("gpu", .{
        .target =  target,
        .optimize = optimize,
        .root_source_file = b.path(src_path ++ "gpu.zig"),
    });
    lib_mod.addImport("gpu", gpu);
        //Vulkan Modules 
        const vk_graphics_context = b.addModule("vk_graphics_context", .{
            .target =  target,
            .optimize = optimize,
            .root_source_file = b.path(src_path ++ "vulkan/graphics_context.zig"),
        });
        gpu.addImport("vk_graphics_context", vk_graphics_context);

        const vk_swapchain = b.addModule("vk_swapchain", .{
            .target =  target,
            .optimize = optimize,
            .root_source_file = b.path(src_path ++ "vulkan/swapchain.zig"),
        });
        vk_swapchain.addImport("vk_graphics_context", vk_graphics_context);
        gpu.addImport("vk_swapchain", vk_swapchain);

        const vk_pipeline = b.addModule("vk_pipeline", .{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path(src_path ++ "vulkan/pipeline.zig" ),
        });
        vk_pipeline.addImport("gpu", gpu);
        vk_pipeline.addImport("vk_graphics_context", vk_graphics_context);
        gpu.addImport("vk_pipeline",vk_pipeline);


        const vk_render_pass = b.addModule("vk_render_pass", .{
            .target =  target,
            .optimize = optimize,
            .root_source_file = b.path(src_path ++ "vulkan/render_pass.zig")
        });
        vk_render_pass.addImport("vk_graphics_context", vk_graphics_context);
        vk_render_pass.addImport("vk_swapchain", vk_swapchain);
        gpu.addImport("vk_render_pass", vk_render_pass);

        const vk_frame_buffer = b.addModule("vk_frame_buffer", .{
            .target =  target,
            .optimize = optimize,
            .root_source_file = b.path(src_path ++ "vulkan/frame_buffer.zig")
        });
        vk_frame_buffer.addImport("vk_graphics_context", vk_graphics_context);
        vk_frame_buffer.addImport("vk_swapchain", vk_swapchain);
        gpu.addImport("vk_frame_buffer", vk_frame_buffer);

        const vk_command_buffer = b.addModule("vk_command_buffer", .{
            .target =  target,
            .optimize = optimize,
            .root_source_file = b.path(src_path ++ "vulkan/command_buffer.zig")
        });
        vk_command_buffer.addImport("vk_graphics_context", vk_graphics_context);
        gpu.addImport("vk_command_buffer", vk_command_buffer);

  
    

    //Dependencies
    var zwin = b.createModule(.{});
    //wayland linking 
    if (target.result.os.tag == .linux) {
        const Scanner = @import("zig_wayland").Scanner;
        const scanner = Scanner.create(b, .{});
        const wayland = b.createModule(.{.root_source_file = scanner.result});
        scanner.addSystemProtocol("stable/xdg-shell/xdg-shell.xml");
        // Pass the maximum version implemented by your wayland server or client.
        // Requests, events, enums, etc. from newer versions will not be generated,
        // ensuring forwards compatibility with newer protocol xml.
        // This will also generate code for interfaces created using the provided
        // global interface, in this example wl_keyboard, wl_pointer, xdg_surface,
        // xdg_toplevel, etc. would be generated as well.
        scanner.generate("wl_compositor",1);
        scanner.generate("wl_shm", 2);
        scanner.generate("xdg_wm_base", 3);
        scanner.generate("wl_seat",4);
        lib_mod.addImport("zig_wayland", wayland);
        lib.linkLibC();
        lib.linkSystemLibrary("wayland-client");

        zwin.root_source_file = b.path(src_path ++ "os/wayland-zwin.zig");
        zwin.addImport("wayland", wayland);
    }
    lib_mod.addImport("zwin", zwin);
    gpu.addImport("zwin", zwin);
    vk_graphics_context.addImport("zwin", zwin);
    

    const vulkan_headers = b.dependency("vulkan_headers",.{});
    const vulkan = b.dependency("vulkan_zig", .{
        .registry = vulkan_headers.path("registry/vk.xml"),
    }).module("vulkan-zig");
    zwin.addImport("vulkan", vulkan);
    gpu.addImport("vulkan", vulkan);
    lib_mod.addImport("vulkan", vulkan);
    vk_graphics_context.addImport("vulkan", vulkan);
    vk_swapchain.addImport("vulkan", vulkan);
    vk_render_pass.addImport("vulkan", vulkan);
    vk_pipeline.addImport("vulkan", vulkan);
    vk_frame_buffer.addImport("vulkan", vulkan);
    vk_command_buffer.addImport("vulkan", vulkan);    

//  const zglfw = b.dependency("zglfw", .{
//      .target = target,
//      .optimize = optimize,
//      .import_vulkan = true,
//  });
//  if (target.result.os.tag == .linux) {
//      zglfw.module("root").addLibraryPath(
//          std.Build.LazyPath{.cwd_relative = "/usr/lib"}
//      );
//  }
//  zglfw.module("root").addImport("vulkan", vulkan);
//  lib_mod.addImport("zglfw", zglfw.module("root"));
//  gpu.addImport("zglfw", zglfw.module("root"));
//  vk_graphics_context.addImport("zglfw", zglfw.module("root"));
//
//  const zmath = b.dependency("zmath", .{
//      .target = target,
//  });
//  lib_mod.addImport("zmath", zmath.module("root"));
// 
//  const zgltf = b.dependency("zgltf", .{
//      .target =  target,
//      .optimize = optimize,
//  });
//  lib_mod.addImport("zgltf", zgltf.module("zgltf"));
// 
//  const zstbi = b.dependency("zstbi", .{});
//  lib_mod.addImport("zstbi", zstbi.module("root"));
// 
//  const TrueType = b.dependency("TrueType", .{
//      .target = target,
//      .optimize = optimize,
//  });
//  lib_mod.addImport("TrueType", TrueType.module("TrueType"));
//
    //Link Generated / System Libraries
//  lib.root_module.linkLibrary(zglfw.artifact("glfw")); 
//

    //copy content_dir to output
    const content_path = b.pathJoin(&.{cwd_path, content_dir});
    const exe_options = b.addOptions();
    exe.root_module.addOptions("build_options",exe_options);
    exe_options.addOption([]const u8, "content_dir", content_path);

    //install content to bin
    const install_content_step = b.addInstallDirectory(.{
        .source_dir = b.path(content_path),
        .install_dir = .{ .custom = "" },
        .install_subdir = b.pathJoin(&.{ "bin", content_dir }),
    });
    exe.step.dependOn(&install_content_step.step);
    b.installArtifact(lib);

    //Compile generate and embed shaders
    if (use_zig_shaders) {
        //zig shaders not implemented
    } else {
        const vert_cmd = b.addSystemCommand(&.{
            "glslang",
            "-V",
            "-o",
        });
        const vert_spv = vert_cmd.addOutputFileArg("base_vert.spv");
        vert_cmd.addFileArg(b.path(src_path ++ "shaders/base.vert"));
        gpu.addAnonymousImport("vertex_shader", .{
            .root_source_file = vert_spv,
        });

        const frag_cmd = b.addSystemCommand(&.{
            "glslang",
            "-V",
            "-o",
        });
        const frag_spv = frag_cmd.addOutputFileArg("base_frag.spv");
        frag_cmd.addFileArg(b.path(src_path ++ "shaders/base.frag"));
        gpu.addAnonymousImport("fragment_shader", .{
            .root_source_file = frag_spv,
        });
    }
    
    return exe;
}
