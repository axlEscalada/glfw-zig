const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const opt = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{ .name = "video-editor", .root_source_file = .{ .path = "src/main.zig" }, .target = target, .optimize = opt });
    exe.linkSystemLibrary("glfw");
    exe.linkSystemLibrary("GL");
    exe.addCSourceFile(.{ .file = b.path("glad/src/glad.c") });
    exe.addIncludePath(b.path("glad/include"));
    exe.linkLibC();
    b.installArtifact(exe);
}
