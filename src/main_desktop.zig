const std = @import("std");
const gem = @import("gem");
const ash = @import("ash");

const app = @import("app.zig");

const app_name = "gem-example";

fn errorCallback(error_code: ash.glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}", .{ error_code, description });
}

pub fn main() !void {
    ash.glfw.setErrorCallback(errorCallback);

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const engine = try gem.Engine.init(allocator, .{
        .title = app_name,
        .width = 800,
        .height = 600,
    });
    defer engine.deinit();

    try app.run(engine, allocator);
}
