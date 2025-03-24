const std = @import("std");
const w32 = @import("bindings/win32.zig");
const dx = @import("bindings/directx.zig");
const wic = @import("bindings/wincodec.zig");
const imgui = @import("bindings/imgui.zig");
const imgui_w32 = @import("bindings/imgui_win32.zig");
const imgui_dx11 = @import("bindings/imgui_dx11.zig");
const App = @import("app.zig");

const MAIN_WINDOW_CLASS = "WPMNGR";

pub fn main() !void {
    loghresult("CoInitialize", w32.CoInitializeEx(null, 0));
    defer loghresult("CoUninitialize", w32.CoUninitialize());

    var wicfac: ?*wic.IWICImagingFactory = null;
    loghresult("CoCreateInstance", w32.CoCreateInstance(
        &wic.IWICImagingFactory.CLSID,
        null,
        w32.CLSCTX_INPROC_SERVER,
        &wic.IWICImagingFactory.IID,
        @ptrCast(&wicfac),
    ));
    defer _ = wicfac.?.Unknown.Release();

    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip(); // Skip the command itself.
    const imgpath = try (args.next() orelse error.MissingImageArg);
    const imgpathw = try std.unicode.wtf8ToWtf16LeAllocZ(allocator, imgpath);
    defer allocator.free(imgpathw);
    args.deinit();

    var decoder: ?*wic.IWICBitmapDecoder = null;
    loghresult("CreateDecoderFromFilename", wicfac.?.ImagingFactory.CreateDecoderFromFilename(
        imgpathw,
        null,
        .{ .read = true },
        .{ .cache_metadata_on_load = true },
        &decoder,
    ));
    defer _ = decoder.?.Unknown.Release();

    var frame: ?*wic.IWICBitmapFrameDecode = null;
    loghresult("Get Frame", decoder.?.BitmapDecoder.GetFrame(0, &frame));
    defer _ = frame.?.Unknown.Release();

    var img_conv: ?*wic.IWICFormatConverter = null;
    loghresult(
        "Create Format Converter",
        wicfac.?.ImagingFactory.CreateFormatConverter(&img_conv),
    );
    defer _ = img_conv.?.Unknown.Release();
    loghresult("Initialize Format Converter", img_conv.?.FormatConverter.Initialize(
        @as(*wic.IWICBitmapSource, @ptrCast(frame.?)),
        &wic.GUID_WICPixelFormat32bppRGBA,
        .none,
        null,
        0.0,
        0,
    ));

    var width: u32 = undefined;
    var height: u32 = undefined;
    loghresult("Get Bitmap Size", img_conv.?.BitmapSource.GetSize(&width, &height));

    const imgbfr = try allocator.alloc(u8, width * height * 4);

    loghresult(
        "Copy Pixels",
        img_conv.?.BitmapSource.CopyPixels(null, width * 4, imgbfr),
    );

    var desc = std.mem.zeroes(dx.D3D11_TEXTURE2D_DESC);
    desc.Width = width;
    desc.Height = height;
    desc.MipLevels = 0;
    desc.ArraySize = 1;
    desc.Format = .R8G8B8A8_UNORM;
    desc.SampleDesc.Count = 1;
    desc.Usage = .DEFAULT;
    desc.BindFlags = .{ .SHADER_RESOURCE = true, .RENDER_TARGET = true };
    desc.MiscFlags = .{ .GENERATE_MIPS = true };

    const imctx = imgui.init(allocator);
    defer imgui.deinit(imctx);
    imgui.config.SetFlags(.{ .DockingEnable = true });

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
    const wstyle = w32.WS_OVERLAPPEDWINDOW | w32.WS_VISIBLE | w32.WS_MAXIMIZE;
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

    try imgui_w32.init(hwnd.?);
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

    loghresult("Create Device and Swap Chain", dx.D3D11CreateDeviceAndSwapChain(
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
    ));

    var sampler: ?*dx.ID3D11SamplerState = null;

    const samplerdesc: dx.D3D11_SAMPLER_DESC = .{
        .MinLOD = 0,
        .MaxLOD = 14,
        .MipLODBias = 0,
        .MaxAnisotropy = 16,
        .ComparisonFunc = .equal,
        .BorderColor = @splat(0),
        .AddressW = .clamp,
        .AddressV = .clamp,
        .AddressU = .clamp,
        .Filter = .min_linear_mag_point_mip_linear,
    };

    loghresult(
        "Create Sampler",
        dev.?.Device.CreateSamplerState(&samplerdesc, &sampler),
    );

    var gctx: Context = .{
        .devctx = devctx.?,
        .mainRTV = null,
        .sc = sc.?,
        .dev = dev.?,
        .app = .init(set_sampler, set_diff_blender),
    };

    defer _ = gctx.dev.Unknown.Release();
    defer _ = gctx.devctx.Unknown.Release();
    defer _ = gctx.sc.Unknown.Release();
    defer if (gctx.mainRTV) |rtv| {
        _ = rtv.Unknown.Release();
    };

    var texture: ?*dx.ID3D11Texture2D = null;
    loghresult("Create Texture2D", gctx.dev.Device.CreateTexture2D(
        &desc,
        null,
        &texture,
    ));
    defer _ = texture.?.Unknown.Release();

    var srv: ?*dx.ID3D11ShaderResourceView = null;
    loghresult("Create SRV", gctx.dev.Device.CreateShaderResourceView(
        @ptrCast(texture.?),
        null,
        &srv,
    ));

    gctx.devctx.DeviceContext.UpdateSubresource(
        @ptrCast(texture.?),
        0,
        null,
        @ptrCast(imgbfr.ptr),
        width * 4,
        height * width * 4,
    );

    var fmt_support: dx.D3D11_FORMAT_SUPPORT = undefined;
    loghresult(
        "Check format support",
        gctx.dev.Device.CheckFormatSupport(desc.Format, &fmt_support),
    );
    if (fmt_support.mip_autogen) {
        gctx.devctx.DeviceContext.GenerateMips(srv.?);
    } else {
        std.log.warn("We do not support mip gen", .{});
    }

    allocator.free(imgbfr);
    if (srv) |t| {
        gctx.app.image = .{
            .txid = t,
            .dims = .{
                @floatFromInt(width),
                @floatFromInt(height),
            },
            .sampler = sampler.?,
        };
        gctx.app.set_full_roi();
    }
    defer if (srv) |t| {
        _ = t.Unknown.Release();
    };

    try imgui_dx11.init(gctx.dev, gctx.devctx);
    defer imgui_dx11.deinit();

    var backbfr: ?*dx.ID3D11Texture2D = null;
    loghresult(
        "Get SwapChain Buffer",
        gctx.sc.SwapChain.GetBuffer(0, &dx.ID3D11Texture2D.IID, @ptrCast(&backbfr)),
    );
    loghresult(
        "Create RTV",
        gctx.dev.Device.CreateRenderTargetView(@ptrCast(backbfr), null, @ptrCast(&gctx.mainRTV)),
    );
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
        try gctx.paint();
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
                if (ctx.paint()) {} else |err| {
                    std.log.err("paint error: {any}", .{err});
                }
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
    app: App,

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

    pub fn paint(ctx: *Context) !void {
        imgui_dx11.newFrame();
        imgui_w32.newFrame();
        imgui.newFrame();

        try ctx.app.update();

        ctx.devctx.DeviceContext.OMSetRenderTargets(1, &.{ctx.mainRTV.?}, null);
        ctx.devctx.DeviceContext.ClearRenderTargetView(ctx.mainRTV.?, &.{ 0.45, 0.55, 0.60, 1.00 });

        imgui.render();
        imgui_dx11.render(imgui.getDrawData());

        _ = ctx.sc.SwapChain.Present(1, .{});
    }
};

fn loghresult(name: []const u8, hr: w32.HRESULT) void {
    if (hr == w32.S_OK) return;
    const uhr: u32 = @as(u32, @bitCast(hr));
    if (uhr & 0xffff_0000 == 0) {
        const w32err = w32.HRESULT_CODE(hr);
        std.log.err("{s}:\t0x{x} - {any}", .{ name, uhr, w32err });
    } else {
        std.log.err("{s}\t0x{x}", .{ name, uhr });
    }
}

fn set_sampler(drawlist_: *const anyopaque, cmd_: *const anyopaque) callconv(.c) void {
    _ = drawlist_;
    const cmd: *const imgui.draw.Cmd = @ptrCast(@alignCast(cmd_));
    if (cmd.UserCallbackData) |cbdata| {
        const sampler: *const dx.ID3D11SamplerState = @ptrCast(@alignCast(cbdata));
        const rstate: *imgui_dx11.RenderState = @ptrCast(@alignCast(imgui.platform.getRenderState()));
        const samplers: [1]*const dx.ID3D11SamplerState = .{sampler};
        rstate.device_ctx.DeviceContext.PSSetSamplers(0, &samplers);
    }
}

fn set_diff_blender(drawlist_: *const anyopaque, cmd_: *const anyopaque) callconv(.c) void {
    _ = drawlist_;
    _ = cmd_;
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

    loghresult(
        "Create Blend State",
        rstate.device.Device.CreateBlendState(&blendDesc, &blendState),
    );
    rstate.device_ctx.DeviceContext.OMSetBlendState(blendState, &.{ 0, 0, 0, 0 }, 0xffff_ffff);
}
