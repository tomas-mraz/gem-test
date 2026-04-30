//! Shared scene wiring used by both desktop and Android entry points.
const std = @import("std");
const gem = @import("gem");

const Scene1 = @import("scene1.zig").Scene1;
const Scene2 = @import("scene2.zig").Scene2;
const Scene3 = @import("scene3.zig").Scene3;
const sceneevent = @import("sceneevent.zig");

pub fn registerScenes(
    engine: *gem.Engine,
    scene_intro: *Scene1,
    scene_game: *Scene2,
    scene_menu: *Scene3,
) !void {
    const manager = &engine.scene_manager;

    try manager.register("intro", scene_intro.scene());
    try manager.register("game", scene_game.scene());
    try manager.register("menu", scene_menu.scene());

    try manager.bind("intro", sceneevent.intro_finished, "game");
    try manager.bind("game", sceneevent.open_menu, "menu");
    try manager.bind("menu", sceneevent.resume_game, "game");
}

pub fn run(engine: *gem.Engine, allocator: std.mem.Allocator) !void {
    var scene_intro = Scene1.init(allocator);
    defer scene_intro.deinit();
    var scene_game = Scene2.init(allocator);
    defer scene_game.deinit();
    var scene_menu = Scene3.init(allocator);
    defer scene_menu.deinit();

    try registerScenes(engine, &scene_intro, &scene_game, &scene_menu);
    try engine.scene_manager.run("intro");
}
