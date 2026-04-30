const std = @import("std");
const gem = @import("gem");
const ash = @import("ash");

const app = @import("app.zig");

const app_name = "gem-example";
const log_tag = "gem-test";

pub const std_options: std.Options = .{
    .logFn = androidLogFn,
    .log_level = .debug,
};

fn androidLogFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime fmt: []const u8,
    args: anytype,
) void {
    _ = scope;
    var buf: [1024]u8 = undefined;
    const text = std.fmt.bufPrintZ(&buf, fmt, args) catch blk: {
        buf[buf.len - 1] = 0;
        break :blk buf[0 .. buf.len - 1 :0];
    };
    const prio: c_int = switch (level) {
        .err => ash.native_app_glue.ANDROID_LOG_ERROR,
        .warn => ash.native_app_glue.ANDROID_LOG_WARN,
        .info => ash.native_app_glue.ANDROID_LOG_INFO,
        .debug => ash.native_app_glue.ANDROID_LOG_DEBUG,
    };
    _ = ash.native_app_glue.__android_log_write(prio, log_tag, text.ptr);
}

pub export fn android_main(android_app: *ash.native_app_glue.android_app) callconv(.c) void {
    var arena = std.heap.ArenaAllocator.init(std.heap.c_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const engine = gem.Engine.initAndroid(allocator, .{
        .title = app_name,
    }, android_app) catch |err| {
        std.log.err("Engine.initAndroid failed: {s}", .{@errorName(err)});
        return;
    };
    defer engine.deinit();

    app.run(engine, allocator) catch |err| {
        std.log.err("app.run failed: {s}", .{@errorName(err)});
    };
}
