//! scene3 — menu: idle-spinning triangle. ESC/Space resumes the game,
//! Enter quits the application.
const std = @import("std");
const gem = @import("gem");
const ash = @import("ash");
const tri = @import("triangle_renderer.zig");
const sceneevent = @import("sceneevent.zig");

const action_resume_game = "resume_game";
const action_quit_game = "quit_game";

const Position = gem.component.Position;
const Color = gem.component.Color;
const Angle = gem.component.Angle;

const MenuTriangleArchetype = struct {
    entity: std.ArrayList(gem.component.EntityID) = .empty,
    position: std.ArrayList(Position) = .empty,
    color: std.ArrayList(Color) = .empty,
    angle: std.ArrayList(Angle) = .empty,

    fn deinit(self: *MenuTriangleArchetype, allocator: std.mem.Allocator) void {
        self.entity.deinit(allocator);
        self.position.deinit(allocator);
        self.color.deinit(allocator);
        self.angle.deinit(allocator);
    }

    fn add(
        self: *MenuTriangleArchetype,
        allocator: std.mem.Allocator,
        position: Position,
        color: Color,
        angle: Angle,
    ) !void {
        try self.entity.append(allocator, gem.component.newEntityID());
        try self.position.append(allocator, position);
        try self.color.append(allocator, color);
        try self.angle.append(allocator, angle);
    }
};

pub const Scene3 = struct {
    allocator: std.mem.Allocator,
    renderer: tri.TriangleRenderer,
    menu_triangle: MenuTriangleArchetype = .{},

    pub fn init(allocator: std.mem.Allocator) Scene3 {
        return .{
            .allocator = allocator,
            .renderer = tri.TriangleRenderer.init(allocator),
        };
    }

    pub fn deinit(self: *Scene3) void {
        self.menu_triangle.deinit(self.allocator);
        self.renderer.deinit();
    }

    fn resetWorld(self: *Scene3) !void {
        self.menu_triangle.deinit(self.allocator);
        self.menu_triangle = .{};
        try self.menu_triangle.add(
            self.allocator,
            .{ .x = 0, .y = 0 },
            .{ .r = 0.65, .g = 0.2, .b = 0.9, .brightness = 1.0 },
            0,
        );
    }

    fn syncRenderer(self: *Scene3) !void {
        const n = self.menu_triangle.entity.items.len;
        var buf = try self.allocator.alloc(tri.TriangleInstance, n);
        defer self.allocator.free(buf);

        for (
            self.menu_triangle.position.items,
            self.menu_triangle.angle.items,
            self.menu_triangle.color.items,
            0..,
        ) |pos, ang, c, i| {
            buf[i] = .{
                .angle = ang,
                .offset_x = pos.x,
                .offset_y = pos.y,
                .color_r = c.r * c.brightness,
                .color_g = c.g * c.brightness,
                .color_b = c.b * c.brightness,
            };
        }
        try self.renderer.setInstances(buf);
    }

    fn updateIdleSpin(self: *Scene3, e: *gem.Engine) void {
        const spin: Angle = @as(f32, @floatCast(e.deltaTime() * 1.25));
        for (self.menu_triangle.angle.items) |*ang| {
            ang.* += spin;
        }
    }

    // -- gem.Scene methods ----------------------------------------------------

    pub fn load(self: *Scene3, e: *gem.Engine) !void {
        _ = e;
        try self.renderer.loadResources();
        try self.resetWorld();
        try self.syncRenderer();
    }

    pub fn enter(self: *Scene3, e: *gem.Engine) !void {
        _ = e;
        try self.resetWorld();
        self.renderer.reset();
        try self.syncRenderer();
    }

    pub fn update(self: *Scene3, e: *gem.Engine) bool {
        if (e.actions.justPressed(action_quit_game)) {
            // No event emitted: scene_manager treats `update returning true` with
            // no pending event as a close request and shuts the host down.
            return true;
        }
        if (e.actions.justPressed(action_resume_game)) {
            e.scene_manager.emit(sceneevent.resume_game);
            return true;
        }
        self.updateIdleSpin(e);
        self.syncRenderer() catch {};
        return false;
    }

    pub fn exitFn(self: *Scene3, e: *gem.Engine) void {
        _ = self;
        _ = e;
    }

    pub fn unload(self: *Scene3, e: *gem.Engine) void {
        _ = self;
        _ = e;
    }

    pub fn actions(self: *Scene3) gem.ActionMap {
        _ = self;
        return .{
            .digital = &.{
                .{ .action = action_resume_game, .key = .escape },
                .{ .action = action_resume_game, .key = .space },
                .{ .action = action_quit_game, .key = .enter },
            },
        };
    }

    // -- vtable adapters ------------------------------------------------------

    pub fn scene(self: *Scene3) gem.Scene {
        return .{ .ptr = self, .vtable = &scene_vtable };
    }

    const scene_vtable: gem.Scene.VTable = .{
        .load = loadAdapter,
        .enter = enterAdapter,
        .update = updateAdapter,
        .exit = exitAdapter,
        .unload = unloadAdapter,
        .actions = actionsAdapter,
        .renderer = rendererAdapter,
    };

    fn loadAdapter(ptr: *anyopaque, e: *gem.Engine) anyerror!void {
        const self: *Scene3 = @ptrCast(@alignCast(ptr));
        return self.load(e);
    }
    fn enterAdapter(ptr: *anyopaque, e: *gem.Engine) anyerror!void {
        const self: *Scene3 = @ptrCast(@alignCast(ptr));
        return self.enter(e);
    }
    fn updateAdapter(ptr: *anyopaque, e: *gem.Engine) bool {
        const self: *Scene3 = @ptrCast(@alignCast(ptr));
        return self.update(e);
    }
    fn exitAdapter(ptr: *anyopaque, e: *gem.Engine) void {
        const self: *Scene3 = @ptrCast(@alignCast(ptr));
        self.exitFn(e);
    }
    fn unloadAdapter(ptr: *anyopaque, e: *gem.Engine) void {
        const self: *Scene3 = @ptrCast(@alignCast(ptr));
        self.unload(e);
    }
    fn actionsAdapter(ptr: *anyopaque) gem.ActionMap {
        const self: *Scene3 = @ptrCast(@alignCast(ptr));
        return self.actions();
    }
    fn rendererAdapter(ptr: *anyopaque) gem.Renderer {
        const self: *Scene3 = @ptrCast(@alignCast(ptr));
        return self.renderer.renderer();
    }
};
