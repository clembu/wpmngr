const std = @import("std");
const imgui = @import("bindings/imgui.zig");
const vec = @import("vec.zig");
const spsc = @import("spsc.zig");
const Cropper = @import("cropper.zig");
const Image = @import("image.zig");

cropper: ?Cropper,
db_ready: bool,
op_err: ?anyerror,
test_image_filename: [255:0]u8,

pub fn init() @This() {
    return .{
        .cropper = null,
        .db_ready = false,
        .op_err = null,
        .test_image_filename = @splat(0),
    };
}

pub fn set_image(self: *@This(), image: Image) void {
    self.cropper = .init(image, .{ 9, 16 }, .{ 1080, 1920 });
}

pub fn update(self: *@This(), req: *WorkMsgQueue) !void {
    if (self.cropper == null) {
        _ = imgui.input.text("Test image filename", &self.test_image_filename, .{});
        if (imgui.button("Load Test Image", .{})) {
            _ = req.send(.{ .load_image_file = std.mem.span(self.test_image_filename[0..].ptr) });
        }
    }

    _ = imgui.dockSpace.overViewport(.{});
    if (self.cropper) |*cr| try cr.update();
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

    if (self.op_err) |err| {
        const show_win = imgui.window.begin("Error", .{});
        defer imgui.window.end();
        if (show_win) {
            try imgui.text("{any}", .{err});
        }
    }
}

pub fn handle_msg(self: *@This(), msg: AppMsg) void {
    switch (msg) {
        .db_ready => self.db_ready = true,
    }
}

pub fn set_error(self: *@This(), err: ?anyerror) void {
    self.op_err = err;
}

pub const WorkMsg = union(enum) {
    load_image_file: [:0]const u8,
    quit,
};
pub const WorkMsgQueue = spsc.SPSC(WorkMsg, 64);

pub const AppMsg = union(enum) {
    db_ready,
};
