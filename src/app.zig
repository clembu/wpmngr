const std = @import("std");
const imgui = @import("bindings/imgui.zig");

image: ?Image,
set_sampler: imgui.DrawCallback,

pub fn init(set_sampler: imgui.DrawCallback) @This() {
    return .{
        .image = null,
        .set_sampler = set_sampler,
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

            imgui.getWindowDrawList().addCallback(self.set_sampler, img.sampler);

            imgui.image(img.txid, .{ .size = .{
                avail[1] / imgheightf * imgwidtf,
                avail[1],
            } });
            imgui.getWindowDrawList().addResetCallback();
        }
    }
    imgui.end();
}

pub const Image = struct {
    txid: imgui.TextureID,
    width: u32,
    height: u32,
    sampler: ?*anyopaque,
};
