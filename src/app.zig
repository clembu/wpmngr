const std = @import("std");
const imgui = @import("bindings/imgui.zig");
// TEMP: Testing D3D11 blend desc
const dx = @import("bindings/directx.zig");

image: ?Image,
blender: BlendState,
set_sampler: imgui.DrawCallback,
set_blender: imgui.DrawCallback,

pub fn init(
    set_sampler: imgui.DrawCallback,
    set_blender: imgui.DrawCallback,
) @This() {
    return .{
        .image = null,
        .set_sampler = set_sampler,
        .set_blender = set_blender,
        .blender = .{},
    };
}

pub fn update(self: *@This()) void {
    const docksp = imgui.dockSpace.overViewport(.{});
    imgui.nextWindow.setDockID(docksp, .appearing);
    if (imgui.begin("Test Window", .{})) {
        if (self.image) |img| {
            const avail = imgui.getContentRegionAvail();
            const imgheightf: f32 = @floatFromInt(img.height);
            const imgwidthf: f32 = @floatFromInt(img.width);

            imgui.getWindowDrawList().addCallback(self.set_sampler, img.sampler);
            const imgpos = imgui.cursor.getScreenPos();
            const imgscrsize = .{
                avail[1] / imgheightf * imgwidthf,
                avail[1],
            };
            imgui.image(img.txid, .{ .size = imgscrsize });
            imgui.getWindowDrawList().addResetCallback();

            imgui.getWindowDrawList().addCallback(self.set_blender, &self.blender);
            imgui.getWindowDrawList().addRect(
                .{
                    imgpos[0] + (imgscrsize[0] * 0.5) - 50,
                    imgpos[1] + (imgscrsize[1] * 0.5) - 50,
                },
                .{
                    imgpos[0] + (imgscrsize[0] * 0.5) + 50,
                    imgpos[1] + (imgscrsize[1] * 0.5) + 50,
                },
                0xffffffff,
                .{
                    .thickness = 8,
                },
            );
            imgui.getWindowDrawList().addResetCallback();
        }
    }
    imgui.end();

    if (imgui.begin("Blend Settings", .{})) {
        enumCombo(dx.D3D11_BLEND, "Src Blend", &self.blender.srcBlend, .{});
        enumCombo(dx.D3D11_BLEND, "Dest Blend", &self.blender.destBlend, .{});
        enumCombo(dx.D3D11_BLEND_OP, "Op", &self.blender.blendOp, .{});
        enumCombo(dx.D3D11_BLEND, "Src Blend Alpha", &self.blender.srcBlendAlpha, .{});
        enumCombo(dx.D3D11_BLEND, "Dest Blend Alpha", &self.blender.destBlendAlpha, .{});
        enumCombo(dx.D3D11_BLEND_OP, "Alpha Op", &self.blender.blendOpAlpha, .{});
    }

    imgui.end();
}

pub const Image = struct {
    txid: imgui.TextureID,
    width: u32,
    height: u32,
    sampler: ?*anyopaque,
};

// TEMP: Testing D3D11 blend desc
pub const BlendState = struct {
    srcBlend: dx.D3D11_BLEND = .one,
    destBlend: dx.D3D11_BLEND = .zero,
    blendOp: dx.D3D11_BLEND_OP = .add,
    srcBlendAlpha: dx.D3D11_BLEND = .one,
    destBlendAlpha: dx.D3D11_BLEND = .zero,
    blendOpAlpha: dx.D3D11_BLEND_OP = .add,
};

pub fn enumCombo(comptime T: type, label: [:0]const u8, value: ?*T, opts: struct {
    flags: imgui.ComboFlags = .{},
}) void {
    const preview = if (value) |v|
        @tagName(v.*)
    else
        null;
    if (imgui.combo.begin(label, preview, .{ .flags = opts.flags })) {
        for (std.enums.values(T)) |v| {
            const selected = if (value) |in_v|
                in_v.* == v
            else
                false;
            if (imgui.selectable(@tagName(v), selected, .{})) {
                if (value) |in_v|
                    in_v.* = v;
            }
        }
        imgui.combo.end();
    }
}
