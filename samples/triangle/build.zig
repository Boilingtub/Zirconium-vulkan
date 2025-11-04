const std = @import("std");
const vkgen = @import("vulkan_zig");

pub fn build(b: *std.Build,
             target:anytype,
             optimize:anytype)
*std.Build.Step.Compile {
    const cwd_path = "samples/triangle";
    const src_path = cwd_path ++ "/src/";
    const content_dir = "/content";
    const maybe_override_registry = b.option([]const u8, "override-registry", "Override the path to the Vulkan registry used for the examples");
    const use_zig_shaders = b.option(bool, "zig-shader", "Use Zig shaders instead of GLSL") orelse false;

    const lib_mod = b.addModule("Zirconium", .{
        .root_source_file = b.path(src_path ++ "root.zig"),
        .target = target,
        .optimize = optimize,
    }); 

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "Zirconium",
        .root_module = lib_mod,
    });

    // Vulkan bindings generation from vulkan Headers
    const registry = b.dependency("vulkan_headers", .{}).path(
        "registry/vk.xml"
    );
    const registry_path: std.Build.LazyPath = 
        if (maybe_override_registry) |override_registry|
            .{ .cwd_relative = override_registry }
    else
        registry;
    
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
    const vulkan = b.dependency("vulkan_zig", .{
        .registry = registry_path,
    }).module("vulkan-zig");
    gpu.addImport("vulkan", vulkan);
    vk_graphics_context.addImport("vulkan", vulkan);
    vk_swapchain.addImport("vulkan", vulkan);
    vk_render_pass.addImport("vulkan", vulkan);
    vk_pipeline.addImport("vulkan", vulkan);
    vk_frame_buffer.addImport("vulkan", vulkan);
    vk_command_buffer.addImport("vulkan", vulkan);    

    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("zglfw", zglfw.module("root"));
    gpu.addImport("zglfw", zglfw.module("root"));
    vk_graphics_context.addImport("zglfw", zglfw.module("root"));

    const zmath = b.dependency("zmath", .{
        .target = target,
    });
    lib_mod.addImport("zmath", zmath.module("root"));

    const zgltf = b.dependency("zgltf", .{
        .target =  target,
        .optimize = optimize,
    });
    lib_mod.addImport("zgltf", zgltf.module("zgltf"));

    const zstbi = b.dependency("zstbi", .{});
    lib_mod.addImport("zstbi", zstbi.module("root"));

    const TrueType = b.dependency("TrueType", .{
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("TrueType", TrueType.module("TrueType"));

    const exe = b.addExecutable(.{
        .name = "zirconium-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path(src_path ++ "main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "Zirconium", .module = lib_mod },
            },
        }),
    });
    
    if (target.result.os.tag != .emscripten) {
        exe.linkLibrary(zglfw.artifact("glfw"));
    }

    if (use_zig_shaders) {
        const spirv_target = b.resolveTargetQuery(.{
            .cpu_arch = .spirv32,
            .os_tag = .vulkan,
            .cpu_model = .{ .explicit = &std.Target.spirv.cpu.vulkan_v1_2 },
            .ofmt = .spirv,
        });

        const vert_spv = b.addObject(.{
            .name = "vertex_shader",
            .root_module = b.createModule(.{
                .root_source_file = b.path(src_path ++ "shaders/vert.zig"),
                .target = spirv_target,
            }),
            .use_llvm = false,
        });
        exe.root_module.addAnonymousImport(
            "vertex_shader",
            .{ .root_source_file = vert_spv.getEmittedBin() },
        );

        const frag_spv = b.addObject(.{
            .name = "fragment_shader",
            .root_module = b.createModule(.{
                .root_source_file = b.path(src_path ++ "shaders/frag.zig"),
                .target = spirv_target,
            }),
            .use_llvm = false,
        });
        exe.root_module.addAnonymousImport(
            "fragment_shader",
            .{ .root_source_file = frag_spv.getEmittedBin() },
        );
    } else {
        const vert_cmd = b.addSystemCommand(&.{
            "glslc",
            "--target-env=vulkan1.2",
            "-o",
        });
        const vert_spv = vert_cmd.addOutputFileArg("base_vert.spv");
        vert_cmd.addFileArg(b.path(src_path ++ "shaders/base.vert"));
        gpu.addAnonymousImport("vertex_shader", .{
            .root_source_file = vert_spv,
        });

        const frag_cmd = b.addSystemCommand(&.{
            "glslc",
            "--target-env=vulkan1.2",
            "-o",
        });
        const frag_spv = frag_cmd.addOutputFileArg("base_frag.spv");
        frag_cmd.addFileArg(b.path(src_path ++ "shaders/base.frag"));
        gpu.addAnonymousImport("fragment_shader", .{
            .root_source_file = frag_spv,
        });
    }

    const content_path = b.pathJoin(&.{cwd_path, content_dir});
    const exe_options = b.addOptions();
    exe.root_module.addOptions("build_options",exe_options);
    exe_options.addOption([]const u8, "content_dir", content_path);

    const install_content_step = b.addInstallDirectory(.{
        .source_dir = b.path(content_path),
        .install_dir = .{ .custom = "" },
        .install_subdir = b.pathJoin(&.{ "bin", content_dir }),
    });
    exe.step.dependOn(&install_content_step.step);

    b.installArtifact(lib);
    return exe;




}
