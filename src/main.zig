const std = @import("std");
const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
    @cInclude("stb_image.h");
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

const Image = struct {
    width: usize,
    height: usize,
    data: []const u8,

    pub fn init(path: [:0]const u8) !Image {
        var width: c_int = undefined;
        var height: c_int = undefined;
        var num_channels: c_int = undefined;
        const data = c.stbi_load(path, &width, &height, &num_channels, 1) orelse {
            std.log.err("failed to load image: {s}\n", .{c.stbi_failure_reason()});
            return error.InvalidData;
        };

        return .{
            .width = @intCast(width),
            .height = @intCast(height),
            .data = data[0..@intCast(width * height)],
        };
    }
};

fn imgToTexture(image: Image) !c.GLuint {
    var texture: c.GLuint = undefined;

    c.glGenTextures(1, &texture);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_REPEAT);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_REPEAT);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR_MIPMAP_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RED, @intCast(image.width), @intCast(image.height), 0, c.GL_RED, c.GL_UNSIGNED_BYTE, image.data.ptr);
    c.glGenerateMipmap(c.GL_TEXTURE_2D);
    return texture;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const alloc = gpa.allocator();
    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len < 2) {
        std.log.err("No image path given", .{});
    }

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
        \\out vec2 vert_coord_2d;
        \\void main()
        \\{
        \\  const vec4 vertices[4] = vec4[](
        \\      vec4(-0.5, -0.5, 0.0, 1.0),
        \\      vec4(0.5, -0.5, 0.0, 1.0),
        \\      vec4(-0.5, 0.5, 0.0, 1.0),
        \\      vec4(0.5, 0.5, 0.0, 1.0)
        \\  );
        \\  vert_coord_2d = vec2(vertices[gl_VertexID].x, vertices[gl_VertexID].y);
        \\  gl_Position = vertices[gl_VertexID];
        \\}
    ;
    const vertex_shader = c.glCreateShader(c.GL_VERTEX_SHADER);
    c.glShaderSource(vertex_shader, 1, &vert_shader_source, null);
    c.glCompileShader(vertex_shader);

    const frag_shader_source: [*c]const u8 =
        \\#version 330
        \\in vec2 vert_coord_2d;
        \\out vec4 fragment;
        \\uniform sampler2D tex;
        \\void main()
        \\{
        \\  vec2 frag_coord = vert_coord_2d + 0.5;
        \\  frag_coord.y *= -1;
        \\  fragment = texture(tex, frag_coord);
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

    const img = try Image.init(args[1]);
    const texture = try imgToTexture(img);

    while (c.glfwWindowShouldClose(window) == 0) {
        var width: c_int = undefined;
        var height: c_int = undefined;

        c.glfwGetFramebufferSize(window, &width, &height);
        c.glViewport(0, 0, width, height);

        c.glClear(c.GL_COLOR_BUFFER_BIT);

        c.glUseProgram(program);
        c.glActiveTexture(c.GL_TEXTURE0);
        c.glBindTexture(c.GL_TEXTURE_2D, texture);
        c.glDrawArrays(c.GL_TRIANGLE_STRIP, 0, 4);

        c.glfwSwapBuffers(window);
    }
    std.debug.print("hello\n", .{});
}
