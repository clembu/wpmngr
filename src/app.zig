const std = @import("std");
const imgui = @import("bindings/imgui.zig");
const vec = @import("vec.zig");
const Cropper = @import("cropper.zig");
const Image = @import("image.zig");

// NOTE: non-optional cropper right now
// because that's what we're working on
cropper: Cropper,

pub fn init(image: Image) @This() {
    return .{
        .cropper = .init(image, .{ 9, 16 }, .{ 1080, 1920 }),
    };
}

pub fn update(self: *@This()) !void {
    _ = imgui.dockSpace.overViewport(.{});
    try self.cropper.update();
}

