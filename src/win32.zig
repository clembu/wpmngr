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
        null,
        &devctx,
    );
    var gctx: Context = .{
        .devctx = devctx.?,
        .mainRTV = null,
        .sc = sc.?,
        .dev = dev.?,
    };

    defer _ = gctx.dev.Unknown.Release();
    defer _ = gctx.devctx.Unknown.Release();
    defer _ = gctx.sc.Unknown.Release();
    defer _ = if (gctx.mainRTV) |rtv| rtv.Unknown.Release();

    _ = try imgui_dx11.init(gctx.dev, gctx.devctx);
    defer imgui_dx11.deinit();

    var backbfr: ?*dx.ID3D11Texture2D = null;
    _ = gctx.sc.SwapChain.GetBuffer(0, &dx.ID3D11Texture2D.IID, @ptrCast(&backbfr));
    _ = gctx.dev.Device.CreateRenderTargetView(@ptrCast(backbfr), null, @ptrCast(&gctx.mainRTV));
    _ = backbfr.?.Unknown.Release();

    _ = w32.setWindowUserData(hwnd.?, &gctx);

    mainloop: while (true) {
        var msg = std.mem.zeroes(w32.MSG);
        while (w32.PeekMessageA(&msg, null, 0, 0, w32.PM_REMOVE) == w32.TRUE) {
            _ = w32.TranslateMessage(&msg);
            _ = w32.DispatchMessageA(&msg);
            if (msg.message == w32.WM_QUIT) {
                break :mainloop;
            }
        }
        gctx.paint();
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
        w32.WM_SIZE => {
            const width: u32 = @intCast(@as(usize, @bitCast(lparam)) & 0xffff);
            const height: u32 = @intCast((@as(usize, @bitCast(lparam)) >> 16) & 0xffff);
            const gctx: ?*Context = w32.getWindowUserData(Context, hwnd);
            if (gctx) |ctx| {
                ctx.resize(width, height);
                return 0;
            }
        },
        w32.WM_SIZING => {
            var rect: w32.RECT = undefined;
            _ = w32.GetClientRect(hwnd, &rect);
            const gctx: ?*Context = w32.getWindowUserData(Context, hwnd);
            if (gctx) |ctx| {
                ctx.resize(
                    @intCast(rect.right - rect.left),
                    @intCast(rect.bottom - rect.top),
                );
                ctx.paint();
                return 0;
            }
        },
        else => {},
    }
    return w32.DefWindowProcA(hwnd, msg, wparam, lparam);
}

const Context = struct {
    dev: *dx.ID3D11Device,
    devctx: *dx.ID3D11DeviceContext,
    mainRTV: ?*dx.ID3D11RenderTargetView,
    sc: *dx.IDXGISwapChain,

    pub fn resize(ctx: *Context, width: u32, height: u32) void {
        ctx.devctx.DeviceContext.OMSetRenderTargets(0, null, null);
        _ = if (ctx.mainRTV) |rtv| rtv.Unknown.Release();
        ctx.devctx.DeviceContext.Flush();
        _ = ctx.sc.SwapChain.ResizeBuffers(1, width, height, .UNKNOWN, .{});
        var backbfr: ?*dx.ID3D11Texture2D = null;
        _ = ctx.sc.SwapChain.GetBuffer(0, &dx.ID3D11Texture2D.IID, @ptrCast(&backbfr));
        std.debug.assert(backbfr != null);
        _ = ctx.dev.Device.CreateRenderTargetView(
            @ptrCast(backbfr),
            null,
            @ptrCast(&ctx.mainRTV),
        );
        _ = backbfr.?.Unknown.Release();
    }

    pub fn paint(ctx: *Context) void {
        imgui_dx11.newFrame();
        imgui_w32.newFrame();
        imgui.newFrame();

        App.update();

        ctx.devctx.DeviceContext.OMSetRenderTargets(1, &.{ctx.mainRTV.?}, null);
        ctx.devctx.DeviceContext.ClearRenderTargetView(ctx.mainRTV.?, &.{ 0.45, 0.55, 0.60, 1.00 });

        imgui.render();
        imgui_dx11.render(imgui.getDrawData());

        _ = ctx.sc.SwapChain.Present(1, .{});
    }
};
