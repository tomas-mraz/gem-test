//! scene2 — game: WASD-controlled triangle. ESC opens the menu.
const std = @import("std");
const gem = @import("gem");
const ash = @import("ash");
const tri = @import("triangle_renderer.zig");
const sceneevent = @import("sceneevent.zig");

const action_move_x = "move_x";
const action_move_y = "move_y";
const action_open_menu = "open_menu";

const Position = gem.component.Position;
const Color = gem.component.Color;
const Angle = gem.component.Angle;

const PlayerTriangleArchetype = struct {
    entity: std.ArrayList(gem.component.EntityID) = .empty,
    position: std.ArrayList(Position) = .empty,
    color: std.ArrayList(Color) = .empty,
    angle: std.ArrayList(Angle) = .empty,
    prev_position: std.ArrayList(Position) = .empty,
    prev_angle: std.ArrayList(Angle) = .empty,

    fn deinit(self: *PlayerTriangleArchetype, allocator: std.mem.Allocator) void {
        self.entity.deinit(allocator);
        self.position.deinit(allocator);
        self.color.deinit(allocator);
        self.angle.deinit(allocator);
        self.prev_position.deinit(allocator);
        self.prev_angle.deinit(allocator);
    }

    fn add(
        self: *PlayerTriangleArchetype,
        allocator: std.mem.Allocator,
        position: Position,
        color: Color,
        angle: Angle,
    ) !void {
        try self.entity.append(allocator, gem.component.newEntityID());
        try self.position.append(allocator, position);
        try self.color.append(allocator, color);
        try self.angle.append(allocator, angle);
        try self.prev_position.append(allocator, position);
        try self.prev_angle.append(allocator, angle);
    }

    fn snapshotPrev(self: *PlayerTriangleArchetype) void {
        @memcpy(self.prev_position.items, self.position.items);
        @memcpy(self.prev_angle.items, self.angle.items);
    }
};

pub const Scene2 = struct {
    allocator: std.mem.Allocator,
    renderer: tri.TriangleRenderer,
    player: PlayerTriangleArchetype = .{},

    pub fn init(allocator: std.mem.Allocator) Scene2 {
        return .{
            .allocator = allocator,
            .renderer = tri.TriangleRenderer.init(allocator),
        };
    }

    pub fn deinit(self: *Scene2) void {
        self.player.deinit(self.allocator);
        self.renderer.deinit();
    }

    fn resetWorld(self: *Scene2) !void {
        self.player.deinit(self.allocator);
        self.player = .{};
        try self.player.add(
            self.allocator,
            .{ .x = 0, .y = 0 },
            .{ .r = 1.0, .g = 0.9, .b = 0.1, .brightness = 1.0 },
            0,
        );
    }

    fn syncRenderer(self: *Scene2) !void {
        const n = self.player.entity.items.len;
        var buf = try self.allocator.alloc(tri.TriangleInstance, n);
        defer self.allocator.free(buf);

        for (
            self.player.position.items,
            self.player.angle.items,
            self.player.color.items,
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

    fn syncRendererInterpolated(self: *Scene2, alpha: f32) !void {
        const inv = 1 - alpha;
        const n = self.player.entity.items.len;
        var buf = try self.allocator.alloc(tri.TriangleInstance, n);
        defer self.allocator.free(buf);

        for (0..n) |i| {
            const px = self.player.prev_position.items[i].x * inv + self.player.position.items[i].x * alpha;
            const py = self.player.prev_position.items[i].y * inv + self.player.position.items[i].y * alpha;
            const pa = self.player.prev_angle.items[i] * inv + self.player.angle.items[i] * alpha;
            const c = self.player.color.items[i];
            buf[i] = .{
                .angle = pa,
                .offset_x = px,
                .offset_y = py,
                .color_r = c.r * c.brightness,
                .color_g = c.g * c.brightness,
                .color_b = c.b * c.brightness,
            };
        }
        try self.renderer.setInstances(buf);
    }

    fn updatePlayer(self: *Scene2, e: *gem.Engine) void {
        const speed: f32 = 0.75;
        const move_x = e.actions.value(action_move_x) * speed * @as(f32, @floatCast(e.deltaTime()));
        const move_y = e.actions.value(action_move_y) * speed * @as(f32, @floatCast(e.deltaTime()));
        const spin: Angle = @as(f32, @floatCast(e.deltaTime() * 2.5));

        for (self.player.position.items, self.player.angle.items) |*pos, *ang| {
            pos.x += move_x;
            pos.y += move_y;
            ang.* += spin;
        }
    }

    // -- gem.Scene methods ----------------------------------------------------

    pub fn load(self: *Scene2, e: *gem.Engine) !void {
        _ = e;
        try self.renderer.loadResources();
        try self.resetWorld();
        try self.syncRenderer();
    }

    pub fn enter(self: *Scene2, e: *gem.Engine) !void {
        _ = e;
        if (self.player.entity.items.len == 0) {
            try self.resetWorld();
        }
        self.renderer.reset();
        try self.syncRenderer();
    }

    pub fn update(self: *Scene2, e: *gem.Engine) bool {
        if (e.actions.justPressed(action_open_menu)) {
            e.scene_manager.emit(sceneevent.open_menu);
            return true;
        }
        self.player.snapshotPrev();
        self.updatePlayer(e);
        return false;
    }

    pub fn preRender(self: *Scene2, e: *gem.Engine) void {
        const alpha: f32 = @floatCast(e.interpolationAlpha());
        self.syncRendererInterpolated(alpha) catch {};
    }

    pub fn exitFn(self: *Scene2, e: *gem.Engine) void {
        _ = self;
        _ = e;
    }

    pub fn unload(self: *Scene2, e: *gem.Engine) void {
        _ = self;
        _ = e;
    }

    pub fn actions(self: *Scene2) gem.ActionMap {
        _ = self;
        return .{
            .digital = &.{
                .{ .action = action_open_menu, .key = .escape },
            },
            .axes = &.{
                .{ .action = action_move_x, .negative = .a, .positive = .d },
                .{ .action = action_move_y, .negative = .w, .positive = .s },
            },
        };
    }

    // -- vtable adapters ------------------------------------------------------

    pub fn scene(self: *Scene2) gem.Scene {
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
        .preRender = preRenderAdapter,
    };

    fn loadAdapter(ptr: *anyopaque, e: *gem.Engine) anyerror!void {
        const self: *Scene2 = @ptrCast(@alignCast(ptr));
        return self.load(e);
    }
    fn enterAdapter(ptr: *anyopaque, e: *gem.Engine) anyerror!void {
        const self: *Scene2 = @ptrCast(@alignCast(ptr));
        return self.enter(e);
    }
    fn updateAdapter(ptr: *anyopaque, e: *gem.Engine) bool {
        const self: *Scene2 = @ptrCast(@alignCast(ptr));
        return self.update(e);
    }
    fn exitAdapter(ptr: *anyopaque, e: *gem.Engine) void {
        const self: *Scene2 = @ptrCast(@alignCast(ptr));
        self.exitFn(e);
    }
    fn unloadAdapter(ptr: *anyopaque, e: *gem.Engine) void {
        const self: *Scene2 = @ptrCast(@alignCast(ptr));
        self.unload(e);
    }
    fn actionsAdapter(ptr: *anyopaque) gem.ActionMap {
        const self: *Scene2 = @ptrCast(@alignCast(ptr));
        return self.actions();
    }
    fn rendererAdapter(ptr: *anyopaque) gem.Renderer {
        const self: *Scene2 = @ptrCast(@alignCast(ptr));
        return self.renderer.renderer();
    }
    fn preRenderAdapter(ptr: *anyopaque, e: *gem.Engine) void {
        const self: *Scene2 = @ptrCast(@alignCast(ptr));
        self.preRender(e);
    }
};
