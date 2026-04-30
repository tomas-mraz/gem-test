//! scene1 — intro: rotating triangle orbiting around a static one. After
//! 10 seconds (or skip-intro action) emits IntroFinished.
const std = @import("std");
const gem = @import("gem");
const ash = @import("ash");
const tri = @import("triangle_renderer.zig");
const sceneevent = @import("sceneevent.zig");

const action_skip_intro = "skip_intro";

const Position = gem.component.Position;
const Color = gem.component.Color;
const Angle = gem.component.Angle;

const RotatingTriangleArchetype = struct {
    entity: std.ArrayList(gem.component.EntityID) = .empty,
    position: std.ArrayList(Position) = .empty,
    velocity: std.ArrayList(gem.component.Velocity) = .empty,
    color: std.ArrayList(Color) = .empty,
    rotation_velocity: std.ArrayList(gem.component.RotationVelocity) = .empty,
    angle: std.ArrayList(Angle) = .empty,

    fn deinit(self: *RotatingTriangleArchetype, allocator: std.mem.Allocator) void {
        self.entity.deinit(allocator);
        self.position.deinit(allocator);
        self.velocity.deinit(allocator);
        self.color.deinit(allocator);
        self.rotation_velocity.deinit(allocator);
        self.angle.deinit(allocator);
    }

    fn add(
        self: *RotatingTriangleArchetype,
        allocator: std.mem.Allocator,
        position: Position,
        velocity: gem.component.Velocity,
        color: Color,
        rotation_velocity: gem.component.RotationVelocity,
        angle: Angle,
    ) !void {
        try self.entity.append(allocator, gem.component.newEntityID());
        try self.position.append(allocator, position);
        try self.velocity.append(allocator, velocity);
        try self.color.append(allocator, color);
        try self.rotation_velocity.append(allocator, rotation_velocity);
        try self.angle.append(allocator, angle);
    }
};

const StaticTriangleArchetype = struct {
    entity: std.ArrayList(gem.component.EntityID) = .empty,
    position: std.ArrayList(Position) = .empty,
    color: std.ArrayList(Color) = .empty,
    angle: std.ArrayList(Angle) = .empty,

    fn deinit(self: *StaticTriangleArchetype, allocator: std.mem.Allocator) void {
        self.entity.deinit(allocator);
        self.position.deinit(allocator);
        self.color.deinit(allocator);
        self.angle.deinit(allocator);
    }

    fn add(
        self: *StaticTriangleArchetype,
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

pub const Scene1 = struct {
    allocator: std.mem.Allocator,
    renderer: tri.TriangleRenderer,
    triangles: RotatingTriangleArchetype = .{},
    static_triangles: StaticTriangleArchetype = .{},

    pub fn init(allocator: std.mem.Allocator) Scene1 {
        return .{
            .allocator = allocator,
            .renderer = tri.TriangleRenderer.init(allocator),
        };
    }

    pub fn deinit(self: *Scene1) void {
        self.triangles.deinit(self.allocator);
        self.static_triangles.deinit(self.allocator);
        self.renderer.deinit();
    }

    fn resetWorld(self: *Scene1) !void {
        self.triangles.deinit(self.allocator);
        self.triangles = .{};
        self.static_triangles.deinit(self.allocator);
        self.static_triangles = .{};

        try self.static_triangles.add(
            self.allocator,
            .{ .x = -0.45, .y = 0 },
            .{ .r = 0.1, .g = 0.9, .b = 0.2, .brightness = 1.0 },
            std.math.pi / 6.0,
        );

        try self.triangles.add(
            self.allocator,
            .{ .x = 0.45, .y = 0 },
            .{ .dx = 0, .dy = 0 },
            .{ .r = 0.2, .g = 0.4, .b = 1.0, .brightness = 1.0 },
            10,
            0,
        );
    }

    fn syncRenderer(self: *Scene1) !void {
        const total = self.static_triangles.entity.items.len + self.triangles.entity.items.len;
        var buf = try self.allocator.alloc(tri.TriangleInstance, total);
        defer self.allocator.free(buf);

        var idx: usize = 0;
        idx += appendStaticInstances(buf[idx..], &self.static_triangles);
        idx += appendRotatingInstances(buf[idx..], &self.triangles);
        try self.renderer.setInstances(buf[0..idx]);
    }

    fn updateOrbit(self: *Scene1, e: *gem.Engine) void {
        const dt: f32 = @floatCast(e.deltaTime());
        const positions = self.triangles.position.items;
        const angles = self.triangles.angle.items;
        for (positions, angles) |*pos, *ang| {
            const x = pos.x;
            const y = pos.y;
            var orbit_angle: f32 = std.math.atan2(y, x);
            const r = std.math.sqrt(x * x + y * y);
            orbit_angle += 1.0 * dt;
            pos.x = r * std.math.cos(orbit_angle);
            pos.y = r * std.math.sin(orbit_angle);
            ang.* += 3.0 * dt;
        }
    }

    // -- gem.Scene methods ----------------------------------------------------

    pub fn load(self: *Scene1, e: *gem.Engine) !void {
        _ = e;
        try self.renderer.loadResources();
        try self.resetWorld();
        try self.syncRenderer();
    }

    pub fn enter(self: *Scene1, e: *gem.Engine) !void {
        _ = e;
        try self.resetWorld();
        self.renderer.reset();
        try self.syncRenderer();
    }

    pub fn update(self: *Scene1, e: *gem.Engine) bool {
        if (e.sceneElapsed() > 10.0 or e.actions.justPressed(action_skip_intro)) {
            e.scene_manager.emit(sceneevent.intro_finished);
            return true;
        }
        self.updateOrbit(e);
        self.syncRenderer() catch {};
        return false;
    }

    pub fn exitFn(self: *Scene1, e: *gem.Engine) void {
        _ = self;
        _ = e;
    }

    pub fn unload(self: *Scene1, e: *gem.Engine) void {
        _ = self;
        _ = e;
    }

    pub fn actions(self: *Scene1) gem.ActionMap {
        _ = self;
        return .{
            .digital = &.{
                .{ .action = action_skip_intro, .key = .space },
                .{ .action = action_skip_intro, .key = .escape },
            },
        };
    }

    // -- vtable adapters ------------------------------------------------------

    pub fn scene(self: *Scene1) gem.Scene {
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
        const self: *Scene1 = @ptrCast(@alignCast(ptr));
        return self.load(e);
    }
    fn enterAdapter(ptr: *anyopaque, e: *gem.Engine) anyerror!void {
        const self: *Scene1 = @ptrCast(@alignCast(ptr));
        return self.enter(e);
    }
    fn updateAdapter(ptr: *anyopaque, e: *gem.Engine) bool {
        const self: *Scene1 = @ptrCast(@alignCast(ptr));
        return self.update(e);
    }
    fn exitAdapter(ptr: *anyopaque, e: *gem.Engine) void {
        const self: *Scene1 = @ptrCast(@alignCast(ptr));
        self.exitFn(e);
    }
    fn unloadAdapter(ptr: *anyopaque, e: *gem.Engine) void {
        const self: *Scene1 = @ptrCast(@alignCast(ptr));
        self.unload(e);
    }
    fn actionsAdapter(ptr: *anyopaque) gem.ActionMap {
        const self: *Scene1 = @ptrCast(@alignCast(ptr));
        return self.actions();
    }
    fn rendererAdapter(ptr: *anyopaque) gem.Renderer {
        const self: *Scene1 = @ptrCast(@alignCast(ptr));
        return self.renderer.renderer();
    }
};

fn appendStaticInstances(dst: []tri.TriangleInstance, a: *const StaticTriangleArchetype) usize {
    for (a.position.items, a.angle.items, a.color.items, 0..) |pos, ang, c, i| {
        dst[i] = .{
            .angle = ang,
            .offset_x = pos.x,
            .offset_y = pos.y,
            .color_r = c.r * c.brightness,
            .color_g = c.g * c.brightness,
            .color_b = c.b * c.brightness,
        };
    }
    return a.position.items.len;
}

fn appendRotatingInstances(dst: []tri.TriangleInstance, a: *const RotatingTriangleArchetype) usize {
    for (a.position.items, a.angle.items, a.color.items, 0..) |pos, ang, c, i| {
        dst[i] = .{
            .angle = ang,
            .offset_x = pos.x,
            .offset_y = pos.y,
            .color_r = c.r * c.brightness,
            .color_g = c.g * c.brightness,
            .color_b = c.b * c.brightness,
        };
    }
    return a.position.items.len;
}
