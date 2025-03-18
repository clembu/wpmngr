const std = @import("std");
const imgui = @import("bindings/imgui.zig");

image: ?Image,

pub fn init() @This() {
    return .{
        .image = null,
    };
}

pub fn update(self: *@This()) void {
    const docksp = imgui.dockSpace.overViewport(.{});
    imgui.nextWindow.setDockID(docksp, .appearing);
    if (imgui.begin("Test Window", .{})) {
        if (self.image) |img| {
            const avail = imgui.getContentRegionAvail();
            const imgheightf: f32 = @floatFromInt(img.height);
            const imgwidtf: f32 = @floatFromInt(img.width);
            imgui.image(img.txid, .{ .size = .{
                avail[1] / imgheightf * imgwidtf,
                avail[1],
            } });
        }
    }
    imgui.end();
}

pub const Image = struct {
    txid: imgui.TextureID,
    width: u32,
    height: u32,
};
