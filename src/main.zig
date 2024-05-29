const std = @import("std");
const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});

fn errorCallback(err: c_int, description: [*c]const u8) callconv(.C) void {
    _ = description;
    _ = err;
    std.debug.print("error happend\n", .{});
    // std.log.err("glfw err {d}: {s}", .{ err, description });
}

fn glDebugCallback(source: c.GLenum, typ: c.GLenum, id: c.GLuint, severity: c.GLenum, length: c.GLsizei, message: [*c]const c.GLchar, user_param: ?*const anyopaque) callconv(.C) void {
    _ = severity;
    _ = source;
    _ = typ;
    _ = length;
    _ = id;
    _ = user_param;
    std.log.err("{s}", .{message});
}

fn checkSupportedPlatform() !void {
    if (c.glfwPlatformSupported(c.GLFW_PLATFORM_X11) == c.GLFW_TRUE) {
        c.glfwInitHint(c.GLFW_PLATFORM, c.GLFW_PLATFORM_X11);
    } else if (c.glfwPlatformSupported(c.GLFW_PLATFORM_WAYLAND) == c.GLFW_TRUE) {
        c.glfwInitHint(c.GLFW_PLATFORM, c.GLFW_PLATFORM_WAYLAND);
    } else if (c.glfwPlatformSupported(c.GLFW_PLATFORM_COCOA) == c.GLFW_TRUE) {
        c.glfwInitHint(c.GLFW_PLATFORM, c.GLFW_PLATFORM_COCOA);
    } else if (c.glfwPlatformSupported(c.GLFW_PLATFORM_WIN32) == c.GLFW_TRUE) {
        c.glfwInitHint(c.GLFW_PLATFORM, c.GLFW_PLATFORM_WIN32);
    } else {
        std.log.err("No supported platform", .{});
        return error.Initialization;
    }
}

pub fn main() !void {
    try checkSupportedPlatform();
    if (c.glfwInit() == c.GLFW_FALSE) {
        std.log.err("Failed error init glfw", .{});
        return error.Initialization;
    }
    defer c.glfwTerminate();
    _ = c.glfwSetErrorCallback(errorCallback);
    c.glfwWindowHint(c.GLFW_CONTEXT_CREATION_API, c.GLFW_EGL_CONTEXT_API);

    const window = c.glfwCreateWindow(640, 480, "Hello, World", null, null) orelse {
        std.log.err("failed to create glfw window", .{});
        return error.Initialization;
    };

    defer c.glfwDestroyWindow(window);

    c.glfwMakeContextCurrent(window);
    if (c.gladLoadGL() == 0) {
        std.log.err("failed to retrieve glad", .{});
        return error.Initialization;
    }

    // c.glfwSetWindowPos(window, 256, 256);

    c.glfwSwapInterval(1);

    c.glEnable(c.GL_DEBUG_OUTPUT);
    c.glDebugMessageCallback(glDebugCallback, null);

    const vert_shader_source: [*c]const u8 =
        \\#version 330 core
        \\void main()
        \\{
        \\  const vec4 vertices[3] = vec4[](
        \\      vec4(-0.5, -0.5, 0.0, 1.0),
        \\      vec4(0.5, -0.5, 0.0, 1.0),
        \\      vec4(0.0, 0.5, 0.0, 1.0)
        \\  );
        \\  gl_Position = vertices[gl_VertexID];
        \\}
    ;
    const vertex_shader = c.glCreateShader(c.GL_VERTEX_SHADER);
    c.glShaderSource(vertex_shader, 1, &vert_shader_source, null);
    c.glCompileShader(vertex_shader);

    const frag_shader_source: [*c]const u8 =
        \\#version 330
        \\out vec4 fragment;
        \\void main()
        \\{
        \\  fragment = vec4(1.0, 0.0, 0.0, 1.0);
        \\}
    ;

    const fragment_shader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    c.glShaderSource(fragment_shader, 1, &frag_shader_source, null);
    c.glCompileShader(fragment_shader);

    const program = c.glCreateProgram();
    c.glAttachShader(program, vertex_shader);
    c.glAttachShader(program, fragment_shader);
    c.glLinkProgram(program);

    c.glClearColor(0.0, 0.0, 1.0, 1.0);
    while (c.glfwWindowShouldClose(window) == 0) {
        var width: c_int = undefined;
        var height: c_int = undefined;

        c.glfwGetFramebufferSize(window, &width, &height);
        c.glViewport(0, 0, width, height);

        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glUseProgram(program);
        c.glDrawArrays(c.GL_TRIANGLES, 0, 3);

        c.glfwSwapBuffers(window);
    }
    std.debug.print("hello\n", .{});
}
