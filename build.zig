const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/win32.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "wpmngr",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const sqlite_mod = b.createModule(.{
        .root_source_file = b.path("src/bindings/sqlite.zig"),
        .target = target,
        .optimize = optimize,
    });
    sqlite_mod.addIncludePath(b.path("vendor/sqlite"));
    sqlite_mod.addCSourceFile(.{ .file = b.path("vendor/sqlite/sqlite3.c") });
    exe_mod.addImport("sqlite", sqlite_mod);

    const imgui = b.addStaticLibrary(.{
        .name = "imgui",
        .target = target,
        .optimize = optimize,
    });
    exe.step.dependOn(&imgui.step);

    imgui.addIncludePath(b.path("vendor/imgui"));
    imgui.addCSourceFiles(.{
        .files = &.{
            "vendor/imgui/imgui.cpp",
            "vendor/imgui/imgui_widgets.cpp",
            "vendor/imgui/imgui_tables.cpp",
            "vendor/imgui/imgui_draw.cpp",
            "vendor/imgui/imgui_demo.cpp",
        },
    });
    imgui.addCSourceFile(.{
        .file = b.path("src/bindings/imgui.cpp"),
    });

    // NOTE(smugs): These are Win32 only
    imgui.addCSourceFiles(.{
        .files = &.{
            "vendor/imgui/backends/imgui_impl_win32.cpp",
            "vendor/imgui/backends/imgui_impl_dx11.cpp",
        },
    });
    imgui.linkSystemLibrary("dwmapi");
    imgui.linkSystemLibrary("d3dcompiler_47");
    imgui.linkSystemLibrary("gdi32");
    imgui.linkSystemLibrary("ole32");
    imgui.root_module.addCMacro("IMGUI_IMPL_API", "extern \"C\"");

    imgui.linkLibC();
    if (target.result.abi != .msvc)
        imgui.linkLibCpp();
    exe.linkLibrary(imgui);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
