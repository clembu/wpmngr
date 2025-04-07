const std = @import("std");
const imgui = @import("bindings/imgui.zig");
const vec = @import("vec.zig");
const spsc = @import("spsc.zig");
const Cropper = @import("cropper.zig");
const Image = @import("image.zig");

// NOTE: non-optional cropper right now
// because that's what we're working on
cropper: Cropper,
db_ready: bool,
com: *Com,

pub fn init(com: *Com, image: Image) @This() {
    return .{
        .cropper = .init(image, .{ 9, 16 }, .{ 1080, 1920 }),
        .com = com,
        .db_ready = false,
    };
}

pub fn update(self: *@This()) !void {
    if (self.com.gui.receive()) |msg| {
        self.handle_msg(msg);
    }
    _ = imgui.dockSpace.overViewport(.{});
    try self.cropper.update();
    {
        const show_win = imgui.window.begin("About SQLite", .{});
        defer imgui.window.end();
        if (show_win) {
            if (self.db_ready) {
                const version = @import("sqlite").lib_version();
                try imgui.text("SQLite Version: {s}", .{version});
            } else {
                imgui.loadingBar(.{ .overlay = "Getting ready" });
            }
        }
    }
}

fn handle_msg(self: *@This(), msg: GuiMsg) void {
    switch (msg) {
        .ready => self.db_ready = true,
    }
}

pub const WorkMsg = union(enum) {
    quit,
};
pub const WorkSPSC = spsc.SPSC(WorkMsg, 64);

pub const GuiMsg = union(enum) {
    ready,
};
pub const GuiSPSC = spsc.SPSC(GuiMsg, 8);

pub const Com = struct {
    work: WorkSPSC = .{},
    gui: GuiSPSC = .{},
};
