const std = @import("std");
const w32 = @import("bindings/win32.zig");
const dx = @import("bindings/directx.zig");
const imgui = @import("bindings/imgui.zig");
const imgui_w32 = @import("bindings/imgui_win32.zig");
const imgui_dx11 = @import("bindings/imgui_dx11.zig");
const App = @import("app.zig");

const MAIN_WINDOW_CLASS = "WPMNGR";

pub fn main() !void {
    const imctx = imgui.init();
    defer imgui.deinit(imctx);
    imgui.io.SetConfigFlags(.ImGuiConfigFlags_DockingEnable);

    const wndClass = w32.WNDCLASSEXA{
        .style = 0,
        .lpfnWndProc = wndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = @ptrCast(w32.GetModuleHandleA(null)),
        .hIcon = null,
        .hCursor = w32.LoadCursorA(null, w32.IDC_ARROW),
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = MAIN_WINDOW_CLASS,
        .hIconSm = null,
    };
    _ = w32.RegisterClassExA(&wndClass);
    const wstyle = w32.WS_OVERLAPPEDWINDOW | w32.WS_VISIBLE;
    const hwnd = w32.CreateWindowExA(
        0,
        MAIN_WINDOW_CLASS,
        "WPMNGR",
        wstyle,
        w32.CW_USEDEFAULT,
        w32.CW_USEDEFAULT,
        800,
        600,
        null,
        null,
        wndClass.hInstance,
        null,
    );

    _ = try imgui_w32.init(hwnd.?);
    defer imgui_w32.deinit();

    const scd: dx.DXGI_SWAP_CHAIN_DESC = .{
        .BufferCount = 2,
        .BufferDesc = .{
            .Width = 0,
            .Height = 0,
            .Format = .R8G8B8A8_UNORM,
            .RefreshRate = .{
                .Numerator = 30,
                .Denominator = 1,
            },
            .Scaling = .UNSPECIFIED,
            .ScanlineOrdering = .UNSPECIFIED,
        },
        .Flags = .{ .ALLOW_MODE_SWITCH = true },
        .BufferUsage = .{ .RENDER_TARGET_OUTPUT = true },
        .OutputWindow = hwnd.?,
        .SampleDesc = .{
            .Count = 1,
            .Quality = 0,
        },
        .Windowed = w32.TRUE,
        .SwapEffect = .DISCARD,
    };

    const featureLevelArray = [_]dx.D3D_FEATURE_LEVEL{
        .@"11_0",
        .@"10_0",
    };

    var sc: ?*dx.IDXGISwapChain = null;
    var dev: ?*dx.ID3D11Device = null;
    var featureLevel: dx.D3D_FEATURE_LEVEL = undefined;
    var devctx: ?*dx.ID3D11DeviceContext = null;

    _ = dx.D3D11CreateDeviceAndSwapChain(
        null,
        .HARDWARE,
        null,
        .{},
        &featureLevelArray,
        featureLevelArray.len,
        dx.D3D11_SDK_VERSION,
        &scd,
        &sc,
        &dev,
        &featureLevel,
        &devctx,
    );
    defer _ = dev.?.Unknown.Release();
    defer _ = devctx.?.Unknown.Release();
    defer _ = sc.?.Unknown.Release();

    _ = try imgui_dx11.init(dev.?, devctx.?);
    defer imgui_dx11.deinit();

    var backbfr: ?*dx.ID3D11Texture2D = null;
    var mainRTV: ?*dx.ID3D11RenderTargetView = null;
    _ = sc.?.SwapChain.GetBuffer(0, &dx.ID3D11Texture2D.IID, @ptrCast(&backbfr));
    _ = dev.?.Device.CreateRenderTargetView(@ptrCast(backbfr), null, @ptrCast(&mainRTV));

    _ = backbfr.?.Unknown.Release();
    defer _ = mainRTV.?.Unknown.Release();

    mainloop: while (true) {
        var msg = std.mem.zeroes(w32.MSG);
        while (w32.PeekMessageA(&msg, null, 0, 0, w32.PM_REMOVE) == w32.TRUE) {
            _ = w32.TranslateMessage(&msg);
            _ = w32.DispatchMessageA(&msg);
            if (msg.message == w32.WM_QUIT) {
                break :mainloop;
            }
        }
        imgui_dx11.newFrame();
        imgui_w32.newFrame();
        imgui.newFrame();

        App.update();

        devctx.?.DeviceContext.OMSetRenderTargets(1, &.{mainRTV.?}, null);
        devctx.?.DeviceContext.ClearRenderTargetView(mainRTV.?, &.{ 0.45, 0.55, 0.60, 1.00 });

        imgui.render();
        imgui_dx11.render(imgui.getDrawData());

        _ = sc.?.SwapChain.Present(1, .{});
    }
}

pub fn wndProc(
    hwnd: w32.HWND,
    msg: w32.UINT,
    wparam: w32.WPARAM,
    lparam: w32.LPARAM,
) callconv(.winapi) w32.LRESULT {
    if (imgui_w32.wndProcHandler(hwnd, msg, wparam, lparam) != 0) {
        return w32.TRUE;
    }
    switch (msg) {
        w32.WM_CLOSE, w32.WM_DESTROY => {
            w32.PostQuitMessage(0);
            return 0;
        },
        else => {},
    }
    return w32.DefWindowProcA(hwnd, msg, wparam, lparam);
}
