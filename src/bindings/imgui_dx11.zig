const imgui = @import("imgui.zig");
const dx = @import("directx.zig");

pub fn init(
    device: *dx.ID3D11Device,
    device_context: *dx.ID3D11DeviceContext,
) error{ImGuiDx11InitError}!void {
    if (!ImGui_ImplDX11_Init(device, device_context)) {
        return error.ImGuiDx11InitError;
    }
}

pub fn deinit() void {
    ImGui_ImplDX11_Shutdown();
}

pub fn newFrame() void {
    ImGui_ImplDX11_NewFrame();
}

pub fn render(data: imgui.DrawData) void {
    ImGui_ImplDX11_RenderDrawData(data);
}

extern fn ImGui_ImplDX11_Init(*dx.ID3D11Device, *dx.ID3D11DeviceContext) bool;
extern fn ImGui_ImplDX11_Shutdown() void;
extern fn ImGui_ImplDX11_NewFrame() void;
extern fn ImGui_ImplDX11_RenderDrawData(imgui.DrawData) void;
