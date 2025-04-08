const std = @import("std");
const w32 = @import("bindings/win32.zig");
const dx = @import("bindings/directx.zig");
const wic = @import("bindings/wincodec.zig");
const imgui = @import("bindings/imgui.zig");
const imgui_w32 = @import("bindings/imgui_win32.zig");
const imgui_dx11 = @import("bindings/imgui_dx11.zig");
const spsc = @import("spsc.zig");
const App = @import("app.zig");
const Image = @import("image.zig");

const MAIN_WINDOW_CLASS = "WPMNGR";

pub fn main() !void {
    try loghresult("CoInitialize", w32.CoInitializeEx(null, 0));
    defer loghresult("CoUninitialize", w32.CoUninitialize()) catch {};

    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    _ = args.skip(); // Skip the command itself.
    const dbpath = try allocator.dupeZ(u8, try (args.next() orelse error.MissingDbPathArg));
    defer allocator.free(dbpath);
    const imgpath = if (args.next()) |arg| try allocator.dupeZ(u8, arg) else null;
    defer if (imgpath) |path| allocator.free(path);
    args.deinit();

    var mbx: Mailbox = .{};

    const worker = try std.Thread.spawn(.{}, run_worker, .{ allocator, &mbx, dbpath });
    defer worker.join();

    if (imgpath) |path| {
        _ = mbx.work.send(.{ .load_image_file = path });
    }

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

    try loghresult("Create Device and Swap Chain", dx.D3D11CreateDeviceAndSwapChain(
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

    var gctx: Context = .{
        .allocator = allocator,
        .mbx = &mbx,
        .devctx = devctx.?,
        .mainRTV = null,
        .sc = sc.?,
        .dev = dev.?,
        .app = .init(),
    };
    defer gctx.deinit();

    try imgui_dx11.init(gctx.dev, gctx.devctx);
    defer imgui_dx11.deinit();

    {
        var backbfr: ?*dx.ID3D11Texture2D = null;
        try loghresult(
            "Get SwapChain Buffer",
            gctx.sc.SwapChain.GetBuffer(0, &dx.ID3D11Texture2D.IID, @ptrCast(&backbfr)),
        );
        defer _ = backbfr.?.Unknown.Release();
        try loghresult(
            "Create RTV",
            gctx.dev.Device.CreateRenderTargetView(@ptrCast(backbfr), null, @ptrCast(&gctx.mainRTV)),
        );
    }

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
    // Keep trying to send the quit message
    while (!mbx.work.send(.quit)) {
        std.Thread.yield() catch {};
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
    allocator: std.mem.Allocator,
    dev: *dx.ID3D11Device,
    devctx: *dx.ID3D11DeviceContext,
    mainRTV: ?*dx.ID3D11RenderTargetView,
    sc: *dx.IDXGISwapChain,
    mbx: *Mailbox,
    app: App,

    pub fn deinit(ctx: *Context) void {
        if (ctx.mainRTV) |rtv| {
            _ = rtv.Unknown.Release();
        }
        _ = ctx.sc.Unknown.Release();
        _ = ctx.devctx.Unknown.Release();
        _ = ctx.dev.Unknown.Release();
    }

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

        if (ctx.mbx.gui.receive()) |msg| {
            ctx.handle_msg(msg);
        }

        try ctx.app.update(&ctx.mbx.work);

        ctx.devctx.DeviceContext.OMSetRenderTargets(1, &.{ctx.mainRTV.?}, null);
        ctx.devctx.DeviceContext.ClearRenderTargetView(ctx.mainRTV.?, &.{ 0.45, 0.55, 0.60, 1.00 });

        imgui.render();
        imgui_dx11.render(imgui.getDrawData());

        _ = ctx.sc.SwapChain.Present(1, .{});
    }

    fn handle_msg(ctx: *Context, msg: GuiMsg) void {
        switch (msg) {
            .noop => {},
            .appmsg => |appmsg| ctx.app.handle_msg(appmsg),
            .load_texture => |ltxe| {
                if (ltxe) |ltx| {
                    if (ctx.upload_texture(ltx.width, ltx.height, ltx.buffer)) |img| {
                        ctx.app.set_image(img);
                    } else |err| {
                        ctx.app.set_error(err);
                    }
                } else |err| {
                    ctx.app.set_error(err);
                }
            },
        }
    }

    fn upload_texture(ctx: *Context, width: u32, height: u32, buffer: []const u8) !Image {
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

        const texture: *dx.ID3D11Texture2D = blk: {
            var texture: ?*dx.ID3D11Texture2D = null;
            try loghresult("Create Texture2D", ctx.dev.Device.CreateTexture2D(
                &desc,
                null,
                &texture,
            ));
            break :blk texture.?;
        };
        defer _ = texture.Unknown.Release();

        const t: *dx.ID3D11ShaderResourceView = blk: {
            var srv: ?*dx.ID3D11ShaderResourceView = null;
            try loghresult("Create SRV", ctx.dev.Device.CreateShaderResourceView(
                @ptrCast(texture),
                null,
                &srv,
            ));
            break :blk srv.?;
        };

        ctx.devctx.DeviceContext.UpdateSubresource(
            @ptrCast(texture),
            0,
            null,
            @ptrCast(buffer.ptr),
            width * 4,
            height * width * 4,
        );

        ctx.allocator.free(buffer);

        var fmt_support: dx.D3D11_FORMAT_SUPPORT = undefined;
        try loghresult(
            "Check format support",
            ctx.dev.Device.CheckFormatSupport(desc.Format, &fmt_support),
        );

        if (fmt_support.mip_autogen) {
            ctx.devctx.DeviceContext.GenerateMips(t);
        } else {
            std.log.warn("We do not support mip gen", .{});
        }

        const sampler = blk: {
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

            try loghresult(
                "Create Sampler",
                ctx.dev.Device.CreateSamplerState(&samplerdesc, &sampler),
            );
            break :blk sampler.?;
        };

        return .{
            .txid = t,
            .dims = .{
                @floatFromInt(width),
                @floatFromInt(height),
            },
            .sampler = sampler,
        };
    }
};

pub fn loghresult(name: []const u8, hr: w32.HRESULT) !void {
    if (hr == w32.S_OK) return;
    const uhr: u32 = @as(u32, @bitCast(hr));
    if (uhr & 0xffff_0000 == 0) {
        const w32err = w32.HRESULT_CODE(hr);
        std.log.err("{s}:\t0x{x} - {any}", .{ name, uhr, w32err });
    } else {
        std.log.err("{s}\t0x{x}", .{ name, uhr });
    }
    return error.Win32HRError;
}

const LoadTextureMsg = struct {
    width: u32,
    height: u32,
    buffer: []const u8,
};
const GuiMsg = union(enum) {
    noop,
    appmsg: App.AppMsg,
    load_texture: error{ImageInitFailed}!LoadTextureMsg,

    pub fn format(
        value: GuiMsg,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try switch (value) {
            .noop => std.fmt.format(writer, "NOOP", .{}),
            .appmsg => |msg| std.fmt.format(writer, "{any}", .{msg}),
            .load_texture => |msg| if (msg) |lt|
                std.fmt.format(
                    writer,
                    "Load Texture {{width: {d}, height: {d}, buffer: _ }}",
                    .{ lt.width, lt.height },
                )
            else |err|
                std.fmt.format(writer, "{any}", .{err}),
        };
    }
};

const Mailbox = struct {
    work: App.WorkMsgQueue = .{},
    gui: spsc.SPSC(GuiMsg, 8) = .{},
};

fn run_worker(allocator: std.mem.Allocator, com: *Mailbox, dbpath: [:0]const u8) !void {
    const sqlite = @import("sqlite");
    const db: sqlite.Db = try .open(dbpath);
    defer {
        var busy = true;
        while (busy) {
            busy = false;
            db.close() catch {
                busy = true;
            };
        }
    }

    while (!com.gui.send(.{ .appmsg = .db_ready })) {}

    const wicfac: *wic.IWICImagingFactory = blk: {
        var wicfac: ?*wic.IWICImagingFactory = null;
        try loghresult("CoCreateInstance", w32.CoCreateInstance(
            &wic.IWICImagingFactory.CLSID,
            null,
            w32.CLSCTX_INPROC_SERVER,
            &wic.IWICImagingFactory.IID,
            @ptrCast(&wicfac),
        ));
        break :blk wicfac.?;
    };
    defer _ = wicfac.Unknown.Release();

    var listen = true;
    while (listen) {
        if (com.work.receive()) |req| {
            switch (req) {
                .load_image_file => |path| {
                    const loaded_image = load_image(wicfac, allocator, path) catch error.ImageInitFailed;
                    while (!com.gui.send(.{ .load_texture = loaded_image })) {}
                },
                .quit => {
                    listen = false;
                },
            }
            std.Thread.yield() catch {};
        } else {
            std.Thread.yield() catch {};
        }
    }
}

fn load_image(
    wicfac: *wic.IWICImagingFactory,
    allocator: std.mem.Allocator,
    path: [:0]const u8,
) !LoadTextureMsg {
    const pathw = try std.unicode.wtf8ToWtf16LeAllocZ(allocator, path);
    defer allocator.free(pathw);

    const decoder = blk: {
        var decoder: ?*wic.IWICBitmapDecoder = null;
        try loghresult("CreateDecoderFromFilename", wicfac.ImagingFactory.CreateDecoderFromFilename(
            pathw,
            null,
            .{ .read = true },
            .{ .cache_metadata_on_load = true },
            &decoder,
        ));

        break :blk decoder.?;
    };
    defer _ = decoder.Unknown.Release();

    const frame = blk: {
        var frame: ?*wic.IWICBitmapFrameDecode = null;
        try loghresult("Get Frame", decoder.BitmapDecoder.GetFrame(0, &frame));
        break :blk frame.?;
    };
    defer _ = frame.Unknown.Release();

    const conv: *wic.IWICFormatConverter = blk: {
        var conv: ?*wic.IWICFormatConverter = null;
        try loghresult(
            "Create Format Converter",
            wicfac.ImagingFactory.CreateFormatConverter(&conv),
        );
        break :blk conv.?;
    };
    defer _ = conv.Unknown.Release();

    try loghresult("Initialize Format Converter", conv.FormatConverter.Initialize(
        @as(*wic.IWICBitmapSource, @ptrCast(frame)),
        &wic.GUID_WICPixelFormat32bppRGBA,
        .none,
        null,
        0.0,
        0,
    ));

    var width: u32 = undefined;
    var height: u32 = undefined;
    try loghresult("Get Bitmap Size", conv.BitmapSource.GetSize(&width, &height));

    const imgbfr = try allocator.alloc(u8, width * height * 4);

    try loghresult(
        "Copy Pixels",
        conv.BitmapSource.CopyPixels(null, width * 4, imgbfr),
    );

    return .{ .width = width, .height = height, .buffer = imgbfr };
}
