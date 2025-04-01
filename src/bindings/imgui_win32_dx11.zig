const std = @import("std");
const w32 = @import("win32.zig");
const dx = @import("directx.zig");
const imgui = @import("imgui.zig");
const imgui_dx11 = @import("imgui_dx11.zig");

pub const Sampler = dx.ID3D11SamplerState;

pub fn set_sampler(_: *const anyopaque, p_cmd: *const anyopaque) callconv(.c) void {
    const cmd: *const imgui.draw.Cmd = @ptrCast(@alignCast(p_cmd));
    if (cmd.UserCallbackData) |cbdata| {
        const sampler: *const Sampler = @ptrCast(@alignCast(cbdata));
        const rstate: *imgui_dx11.RenderState = @ptrCast(@alignCast(imgui.platform.getRenderState()));
        const samplers: [1]*const dx.ID3D11SamplerState = .{sampler};
        rstate.device_ctx.DeviceContext.PSSetSamplers(0, &samplers);
    }
}

pub fn set_diff_blender(_: *const anyopaque, _: *const anyopaque) callconv(.c) void {
    const rstate: *imgui_dx11.RenderState = @ptrCast(@alignCast(imgui.platform.getRenderState()));
    var blendState: ?*dx.ID3D11BlendState = null;
    var blendDesc = std.mem.zeroes(dx.D3D11_BLEND_DESC);
    blendDesc.renderTarget[0].BlendEnable = w32.TRUE;
    blendDesc.renderTarget[0].SrcBlend = .one;
    blendDesc.renderTarget[0].DestBlend = .one;
    blendDesc.renderTarget[0].BlendOp = .subtract;
    blendDesc.renderTarget[0].SrcBlendAlpha = .one;
    blendDesc.renderTarget[0].DestBlendAlpha = .zero;
    blendDesc.renderTarget[0].BlendOpAlpha = .add;
    blendDesc.renderTarget[0].RenderTargetWriteMask = .all;

    const res = rstate.device.Device.CreateBlendState(&blendDesc, &blendState);
    if (res == w32.S_OK) {
        rstate.device_ctx.DeviceContext.OMSetBlendState(blendState, &.{ 0, 0, 0, 0 }, 0xffff_ffff);
    }
    else {
        std.log.err("Could not set the difference blendmode. Got error: 0x{x}", .{res});
    }
}
