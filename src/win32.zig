const std = @import("std");
const w32 = std.os.windows;

const MAIN_WINDOW_CLASS = "WPMNGR";

pub fn main() !void {
    const wndClass = WNDCLASSEXA{
        .style = 0,
        .lpfnWndProc = wndProc,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = @ptrCast(GetModuleHandleA(null)),
        .hIcon = null,
        .hCursor = LoadCursorA(null, IDC_ARROW),
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = MAIN_WINDOW_CLASS,
        .hIconSm = null,
    };
    _ = RegisterClassExA(&wndClass);
    const wstyle = WS_OVERLAPPEDWINDOW | WS_VISIBLE;
    const hwnd = CreateWindowExA(
        0,
        MAIN_WINDOW_CLASS,
        "WPMNGR",
        wstyle,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        800,
        600,
        null,
        null,
        wndClass.hInstance,
        null,
    );

    const scd: DXGI_SWAP_CHAIN_DESC = .{
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

    const featureLevelArray = [_]D3D_FEATURE_LEVEL{
        .@"11_0",
        .@"10_0",
    };

    var sc: ?*IDXGISwapChain = null;
    var dev: ?*ID3D11Device = null;
    var featureLevel: D3D_FEATURE_LEVEL = undefined;
    var devctx: ?*ID3D11DeviceContext = null;

    _ = D3D11CreateDeviceAndSwapChain(
        null,
        .HARDWARE,
        null,
        .{},
        &featureLevelArray,
        featureLevelArray.len,
        D3D11_SDK_VERSION,
        &scd,
        &sc,
        &dev,
        &featureLevel,
        &devctx,
    );
    defer _ = dev.?.Unknown.Release();
    defer _ = devctx.?.Unknown.Release();
    defer _ = sc.?.Unknown.Release();

    var backbfr: ?*ID3D11Texture2D = null;
    var mainRTV: ?*ID3D11RenderTargetView = null;
    _ = sc.?.SwapChain.GetBuffer(0, &ID3D11Texture2D.IID, @ptrCast(&backbfr));
    _ = dev.?.Device.CreateRenderTargetView(@ptrCast(backbfr), null, @ptrCast(&mainRTV));

    _ = backbfr.?.Unknown.Release();
    defer _ = mainRTV.?.Unknown.Release();

    mainloop: while (true) {
        var msg = std.mem.zeroes(MSG);
        while (PeekMessageA(&msg, null, 0, 0, PM_REMOVE) == w32.TRUE) {
            _ = TranslateMessage(&msg);
            _ = DispatchMessageA(&msg);
            if (msg.message == WM_QUIT) {
                break :mainloop;
            }
        }

        devctx.?.DeviceContext.OMSetRenderTargets(1, &.{mainRTV.?}, null);
        devctx.?.DeviceContext.ClearRenderTargetView(mainRTV.?, &.{ 0.45, 0.55, 0.60, 1.00 });

        _ = sc.?.SwapChain.Present(1, .{});
    }
}

pub fn wndProc(
    hwnd: w32.HWND,
    msg: w32.UINT,
    wparam: w32.WPARAM,
    lparam: w32.LPARAM,
) callconv(WINAPI) w32.LRESULT {
    switch (msg) {
        WM_CLOSE, WM_DESTROY => {
            PostQuitMessage(0);
            return 0;
        },
        else => {},
    }
    return DefWindowProcA(hwnd, msg, wparam, lparam);
}

// --------------------------------
// Windows API Declarations
// --------------------------------
// Constant values were taken from MS Docs

const WNDCLASSEXA = extern struct {
    cbSize: w32.UINT = @sizeOf(WNDCLASSEXA),
    style: w32.UINT,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: w32.HINSTANCE,
    hIcon: ?w32.HICON,
    hCursor: ?w32.HCURSOR,
    hbrBackground: ?w32.HBRUSH,
    lpszMenuName: ?w32.LPCSTR,
    lpszClassName: w32.LPCSTR,
    hIconSm: ?w32.HICON,
};

const MSG = extern struct {
    hWnd: ?w32.HWND,
    message: w32.UINT,
    wParam: w32.WPARAM,
    lParam: w32.LPARAM,
    time: w32.DWORD,
    pt: w32.POINT,
    lPrivate: w32.DWORD,
};

extern "user32" fn DefWindowProcA(hwnd: w32.HWND, msg: w32.UINT, wparam: w32.WPARAM, lparam: w32.LPARAM) callconv(WINAPI) w32.LRESULT;
extern "user32" fn CreateWindowExA(dwExStyle: w32.DWORD, lpClassName: ?w32.LPCSTR, lpWindowName: ?w32.LPCSTR, dwStyle: w32.DWORD, X: c_int, Y: c_int, nWidth: c_int, nHeight: c_int, hWindParent: ?w32.HWND, hMenu: ?w32.HMENU, hInstance: w32.HINSTANCE, lpParam: ?w32.LPVOID) callconv(WINAPI) ?w32.HWND;
extern "user32" fn RegisterClassExA(*const WNDCLASSEXA) callconv(WINAPI) w32.ATOM;
extern "kernel32" fn GetModuleHandleA(lpModuleName: ?w32.LPCSTR) callconv(WINAPI) ?w32.HMODULE;

extern "user32" fn LoadCursorA(hInstance: ?w32.HINSTANCE, lpCursorName: ?w32.LPCSTR) callconv(WINAPI) ?w32.HCURSOR;

extern "user32" fn PeekMessageA(lpMsg: *const MSG, hWnd: ?w32.HWND, wMsgFilterMin: w32.UINT, wMsgFilterMax: w32.UINT, wRemoveMsg: w32.UINT) callconv(WINAPI) w32.BOOL;
extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(WINAPI) w32.BOOL;
extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(WINAPI) w32.LRESULT;
extern "user32" fn PostQuitMessage(i32) callconv(WINAPI) void;

const WS_OVERLAPPED: w32.DWORD = 0x0000_0000;
const WS_CAPTION: w32.DWORD = 0x00C0_0000;
const WS_SYSMENU: w32.DWORD = 0x0008_0000;
const WS_THICKFRAME: w32.DWORD = 0x0004_0000;
const WS_MINIMIZEBOX: w32.DWORD = 0x0002_0000;
const WS_MAXIMIZEBOX: w32.DWORD = 0x0001_0000;
const WS_OVERLAPPEDWINDOW: w32.DWORD =
    WS_OVERLAPPED | WS_CAPTION |
    WS_SYSMENU | WS_THICKFRAME |
    WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
const WS_VISIBLE: w32.DWORD = 0x1000_0000;

// NOTE: undocumented value, taken from available SDK source
// in winuser.h
const CW_USEDEFAULT = @as(i32, @bitCast(@as(u32, 0x80000000)));
const IDC_ARROW: w32.LPCSTR = @ptrFromInt(32512);

const PM_REMOVE: w32.UINT = 0x0001;

const WM_QUIT: w32.UINT = 0x0012;
const WM_DESTROY: w32.UINT = 0x0002;
const WM_CLOSE: w32.UINT = 0x0010;

// --- DirectX

extern "d3d11" fn D3D11CreateDeviceAndSwapChain(
    pAdapter: ?*anyopaque, // IDXGIAdapter
    DriverType: D3D_DRIVER_TYPE,
    Software: ?w32.HMODULE,
    Flags: D3D11_CREATE_DEVICE_FLAG,
    pFeatureLevels: ?[*]const D3D_FEATURE_LEVEL,
    FeatureLevels: w32.UINT,
    SDKVersion: w32.UINT,
    pSwapChainDesc: ?*const DXGI_SWAP_CHAIN_DESC,
    ppSwapChain: ?*?*IDXGISwapChain,
    ppDevice: ?*?*ID3D11Device,
    pFeatureLevel: ?*D3D_FEATURE_LEVEL,
    ppImmediateContext: ?*?*ID3D11DeviceContext,
) w32.HRESULT;

const D3D_DRIVER_TYPE = enum(w32.UINT) {
    UNKNOWN = 0,
    HARDWARE = 1,
    REFERENCE = 2,
    NULL = 3,
    SOFTWARE = 4,
    WARP = 5,
};

const D3D11_CREATE_DEVICE_FLAG = packed struct(w32.UINT) {
    SINGLETHREADED: bool = false,
    DEBUG: bool = false,
    SWITCH_TO_REF: bool = false,
    PREVENT_INTERNAL_THREADING_OPTIMIZATIONS: bool = false,
    __unused4: bool = false,
    BGRA_SUPPORT: bool = false,
    DEBUGGABLE: bool = false,
    PREVENT_ALTERING_LAYER_SETTINGS_FROM_REGISTRY: bool = false,
    DISABLE_GPU_TIMEOUT: bool = false,
    __unused9: bool = false,
    __unused10: bool = false,
    VIDEO_SUPPORT: bool = false,
    __unused: u20 = 0,
};

const D3D_FEATURE_LEVEL = enum(w32.UINT) {
    @"1_0_CORE" = 0x1000,
    @"9_1" = 0x9100,
    @"9_2" = 0x9200,
    @"9_3" = 0x9300,
    @"10_0" = 0xa000,
    @"10_1" = 0xa100,
    @"11_0" = 0xb000,
    @"11_1" = 0xb100,
    @"12_0" = 0xc000,
    @"12_1" = 0xc100,
    @"12_2" = 0xc200,
};

const DXGI_SWAP_CHAIN_DESC = extern struct {
    BufferDesc: DXGI_MODE_DESC,
    SampleDesc: DXGI_SAMPLE_DESC,
    BufferUsage: DXGI_USAGE,
    BufferCount: w32.UINT,
    OutputWindow: w32.HWND,
    Windowed: w32.BOOL,
    SwapEffect: DXGI_SWAP_EFFECT,
    Flags: DXGI_SWAP_CHAIN_FLAG,
};

const DXGI_MODE_DESC = extern struct {
    Width: w32.UINT,
    Height: w32.UINT,
    RefreshRate: DXGI_RATIONAL,
    Format: DXGI_FORMAT,
    ScanlineOrdering: DXGI_MODE_SCANLINE_ORDER,
    Scaling: DXGI_MODE_SCALING,
};

const DXGI_RATIONAL = extern struct {
    Numerator: w32.UINT,
    Denominator: w32.UINT,
};

const DXGI_FORMAT = enum(w32.UINT) {
    UNKNOWN = 0,
    R32G32B32A32_TYPELESS = 1,
    R32G32B32A32_FLOAT = 2,
    R32G32B32A32_UINT = 3,
    R32G32B32A32_SINT = 4,
    R32G32B32_TYPELESS = 5,
    R32G32B32_FLOAT = 6,
    R32G32B32_UINT = 7,
    R32G32B32_SINT = 8,
    R16G16B16A16_TYPELESS = 9,
    R16G16B16A16_FLOAT = 10,
    R16G16B16A16_UNORM = 11,
    R16G16B16A16_UINT = 12,
    R16G16B16A16_SNORM = 13,
    R16G16B16A16_SINT = 14,
    R32G32_TYPELESS = 15,
    R32G32_FLOAT = 16,
    R32G32_UINT = 17,
    R32G32_SINT = 18,
    R32G8X24_TYPELESS = 19,
    D32_FLOAT_S8X24_UINT = 20,
    R32_FLOAT_X8X24_TYPELESS = 21,
    X32_TYPELESS_G8X24_UINT = 22,
    R10G10B10A2_TYPELESS = 23,
    R10G10B10A2_UNORM = 24,
    R10G10B10A2_UINT = 25,
    R11G11B10_FLOAT = 26,
    R8G8B8A8_TYPELESS = 27,
    R8G8B8A8_UNORM = 28,
    R8G8B8A8_UNORM_SRGB = 29,
    R8G8B8A8_UINT = 30,
    R8G8B8A8_SNORM = 31,
    R8G8B8A8_SINT = 32,
    R16G16_TYPELESS = 33,
    R16G16_FLOAT = 34,
    R16G16_UNORM = 35,
    R16G16_UINT = 36,
    R16G16_SNORM = 37,
    R16G16_SINT = 38,
    R32_TYPELESS = 39,
    D32_FLOAT = 40,
    R32_FLOAT = 41,
    R32_UINT = 42,
    R32_SINT = 43,
    R24G8_TYPELESS = 44,
    D24_UNORM_S8_UINT = 45,
    R24_UNORM_X8_TYPELESS = 46,
    X24_TYPELESS_G8_UINT = 47,
    R8G8_TYPELESS = 48,
    R8G8_UNORM = 49,
    R8G8_UINT = 50,
    R8G8_SNORM = 51,
    R8G8_SINT = 52,
    R16_TYPELESS = 53,
    R16_FLOAT = 54,
    D16_UNORM = 55,
    R16_UNORM = 56,
    R16_UINT = 57,
    R16_SNORM = 58,
    R16_SINT = 59,
    R8_TYPELESS = 60,
    R8_UNORM = 61,
    R8_UINT = 62,
    R8_SNORM = 63,
    R8_SINT = 64,
    A8_UNORM = 65,
    R1_UNORM = 66,
    R9G9B9E5_SHAREDEXP = 67,
    R8G8_B8G8_UNORM = 68,
    G8R8_G8B8_UNORM = 69,
    BC1_TYPELESS = 70,
    BC1_UNORM = 71,
    BC1_UNORM_SRGB = 72,
    BC2_TYPELESS = 73,
    BC2_UNORM = 74,
    BC2_UNORM_SRGB = 75,
    BC3_TYPELESS = 76,
    BC3_UNORM = 77,
    BC3_UNORM_SRGB = 78,
    BC4_TYPELESS = 79,
    BC4_UNORM = 80,
    BC4_SNORM = 81,
    BC5_TYPELESS = 82,
    BC5_UNORM = 83,
    BC5_SNORM = 84,
    B5G6R5_UNORM = 85,
    B5G5R5A1_UNORM = 86,
    B8G8R8A8_UNORM = 87,
    B8G8R8X8_UNORM = 88,
    R10G10B10_XR_BIAS_A2_UNORM = 89,
    B8G8R8A8_TYPELESS = 90,
    B8G8R8A8_UNORM_SRGB = 91,
    B8G8R8X8_TYPELESS = 92,
    B8G8R8X8_UNORM_SRGB = 93,
    BC6H_TYPELESS = 94,
    BC6H_UF16 = 95,
    BC6H_SF16 = 96,
    BC7_TYPELESS = 97,
    BC7_UNORM = 98,
    BC7_UNORM_SRGB = 99,
    AYUV = 100,
    Y410 = 101,
    Y416 = 102,
    NV12 = 103,
    P010 = 104,
    P016 = 105,
    @"420_OPAQUE" = 106,
    YUY2 = 107,
    Y210 = 108,
    Y216 = 109,
    NV11 = 110,
    AI44 = 111,
    IA44 = 112,
    P8 = 113,
    A8P8 = 114,
    B4G4R4A4_UNORM = 115,
    P208 = 130,
    V208 = 131,
    V408 = 132,
    SAMPLER_FEEDBACK_MIN_MIP_OPAQUE = 189,
    SAMPLER_FEEDBACK_MIP_REGION_USED_OPAQUE = 190,
};

const DXGI_MODE_SCANLINE_ORDER = enum(w32.UINT) {
    UNSPECIFIED = 0,
    PROGRESSIVE = 1,
    UPPER_FIELD_FIRST = 2,
    LOWER_FIELD_FIRST = 3,
};

const DXGI_MODE_SCALING = enum(w32.UINT) {
    UNSPECIFIED = 0,
    CENTERED = 1,
    STRETCHED = 2,
};

const DXGI_SAMPLE_DESC = extern struct {
    Count: w32.UINT,
    Quality: w32.UINT,
};

const DXGI_USAGE = packed struct(w32.UINT) {
    CPU_ACCESS_FIELD: u4 = 0,
    SHADER_INPUT: bool = false,
    RENDER_TARGET_OUTPUT: bool = false,
    BACK_BUFFER: bool = false,
    SHARED: bool = false,
    READ_ONLY: bool = false,
    DISCARD_ON_PRESENT: bool = false,
    UNORDERED_ACCESS: bool = false,
    __unused: u21 = 0,
};

const DXGI_SWAP_EFFECT = enum(w32.UINT) {
    DISCARD = 0,
    SEQUENTIAL = 1,
    FLIP_SEQUENTIAL = 3,
    FLIP_DISCARD = 4,
};

const DXGI_SWAP_CHAIN_FLAG = packed struct(w32.UINT) {
    NONPREROTATED: bool = false,
    ALLOW_MODE_SWITCH: bool = false,
    GDI_COMPATIBLE: bool = false,
    RESTRICTED_CONTENT: bool = false,
    RESTRICT_SHARED_RESOURCE_DRIVER: bool = false,
    DISPLAY_ONLY: bool = false,
    FRAME_LATENCY_WAITABLE_OBJECT: bool = false,
    FOREGROUND_LAYER: bool = false,
    FULLSCREEN_VIDEO: bool = false,
    YUV_VIDEO: bool = false,
    HW_PROTECTED: bool = false,
    ALLOW_TEARING: bool = false,
    RESTRICTED_TO_ALL_HOLOGRAPHIC_DISPLAYS: bool = false,
    __unused: u19 = 0,
};

pub const DXGI_PRESENT = packed struct(w32.UINT) {
    TEST: bool = false,
    DO_NOT_SEQUENCE: bool = false,
    RESTART: bool = false,
    DO_NOT_WAIT: bool = false,
    STEREO_PREFER_RIGHT: bool = false,
    STEREO_TEMPORARY_MONO: bool = false,
    RESTRICT_TO_OUTPUT: bool = false,
    __unused7: bool = false,
    USE_DURATION: bool = false,
    ALLOW_TEARING: bool = false,
    __unused: u22 = 0,
};

const D3D11_SDK_VERSION: w32.UINT = 7;

// Interfaces

pub const IUnknown = extern struct {
    __v: *const VTable,

    Unknown: Mixin(@This()) = .{},

    pub fn Mixin(comptime T: type) type {
        return struct {
            pub inline fn Release(m: *@This()) w32.ULONG {
                const self: *T = @alignCast(@fieldParentPtr("Unknown", m));
                const vt: *const IUnknown.VTable = @ptrCast(self.__v);
                const ctx: *IUnknown = @ptrCast(self);
                return vt.Release(ctx);
            }
        };
    }

    pub const VTable = extern struct {
        QueryInterface: *anyopaque,
        AddRef: *anyopaque,
        Release: *const fn (*IUnknown) callconv(WINAPI) w32.ULONG,
    };
};

pub const IDXGISwapChain = extern struct {
    __v: *const VTable,

    SwapChain: Mixin(@This()) = .{},
    Unknown: IUnknown.Mixin(@This()) = .{},

    pub fn Mixin(comptime T: type) type {
        return struct {
            pub fn Present(m: *@This(), sync_interval: w32.UINT, flags: DXGI_PRESENT) w32.HRESULT {
                const self: *T = @alignCast(@fieldParentPtr("SwapChain", m));
                const vt: *const IDXGISwapChain.VTable = @ptrCast(self.__v);
                const ctx: *IDXGISwapChain = @ptrCast(self);
                return vt.Present(ctx, sync_interval, flags);
            }

            pub fn GetBuffer(m: *@This(), index: u32, guid: *const w32.GUID, surface: *?*anyopaque) w32.HRESULT {
                const self: *T = @alignCast(@fieldParentPtr("SwapChain", m));
                const vt: *const IDXGISwapChain.VTable = @ptrCast(self.__v);
                const ctx: *IDXGISwapChain = @ptrCast(self);
                return vt.GetBuffer(ctx, index, guid, surface);
            }
        };
    }

    pub const VTable = extern struct {
        const T = IDXGISwapChain;
        base: IDXGIDeviceSubObject.VTable,
        Present: *const fn (*T, w32.UINT, DXGI_PRESENT) callconv(WINAPI) w32.HRESULT,
        GetBuffer: *const fn (*T, u32, *const w32.GUID, *?*anyopaque) callconv(WINAPI) w32.HRESULT,
        SetFullscreenState: *anyopaque,
        GetFullscreenState: *anyopaque,
        GetDesc: *anyopaque,
        ResizeBuffers: *anyopaque,
        ResizeTarget: *anyopaque,
        GetContainingOutput: *anyopaque,
        GetFrameStatistics: *anyopaque,
        GetLastPresentCount: *anyopaque,
    };
};

pub const IDXGIDeviceSubObject = extern struct {
    __v: *const VTable,

    pub const VTable = extern struct {
        base: IDXGIObject.VTable,
        GetDevice: *anyopaque,
    };
};

pub const IDXGIObject = extern struct {
    __v: *const VTable,

    pub const VTable = extern struct {
        const T = IDXGIObject;
        base: IUnknown.VTable,
        SetPrivateData: *anyopaque,
        SetPrivateDataInterface: *anyopaque,
        GetPrivateData: *anyopaque,
        GetParent: *anyopaque,
    };
};

pub const ID3D11Device = extern struct {
    __v: *const VTable,

    Device: Mixin(@This()) = .{},
    Unknown: IUnknown.Mixin(@This()) = .{},

    pub fn Mixin(comptime T: type) type {
        return struct {
            pub fn CreateRenderTargetView(
                m: *@This(),
                pResource: ?*ID3D11Resource,
                pDesc: ?*const anyopaque,
                ppSRView: ?*?*ID3D11RenderTargetView,
            ) w32.HRESULT {
                const self: *T = @alignCast(@fieldParentPtr("Device", m));
                const vt: *const ID3D11Device.VTable = @ptrCast(self.__v);
                const ctx: *ID3D11Device = @ptrCast(self);
                return vt.CreateRenderTargetView(ctx, pResource, pDesc, ppSRView);
            }
        };
    }

    pub const VTable = extern struct {
        const T = ID3D11Device;
        base: IUnknown.VTable,
        CreateBuffer: *anyopaque,
        CreateTexture1D: *anyopaque,
        CreateTexture2D: *anyopaque,
        CreateTexture3D: *anyopaque,
        CreateShaderResourceView: *anyopaque,
        CreateUnorderedAccessView: *anyopaque,
        CreateRenderTargetView: *const fn (*T, ?*ID3D11Resource, ?*const anyopaque, ?*?*ID3D11RenderTargetView) callconv(WINAPI) w32.HRESULT,
        CreateDepthStencilView: *anyopaque,
        CreateInputLayout: *anyopaque,
        CreateVertexShader: *anyopaque,
        CreateGeometryShader: *anyopaque,
        CreateGeometryShaderWithStreamOutput: *anyopaque,
        CreatePixelShader: *anyopaque,
        CreateHullShader: *anyopaque,
        CreateDomainShader: *anyopaque,
        CreateComputeShader: *anyopaque,
        CreateClassLinkage: *anyopaque,
        CreateBlendState: *anyopaque,
        CreateDepthStencilState: *anyopaque,
        CreateRasterizerState: *anyopaque,
        CreateSamplerState: *anyopaque,
        CreateQuery: *anyopaque,
        CreatePredicate: *anyopaque,
        CreateCounter: *anyopaque,
        CreateDeferredContext: *anyopaque,
        OpenSharedResource: *anyopaque,
        CheckFormatSupport: *anyopaque,
        CheckMultisampleQualityLevels: *anyopaque,
        CheckCounterInfo: *anyopaque,
        CheckCounter: *anyopaque,
        CheckFeatureSupport: *anyopaque,
        GetPrivateData: *anyopaque,
        SetPrivateData: *anyopaque,
        SetPrivateDataInterface: *anyopaque,
        GetFeatureLevel: *anyopaque,
        GetCreationFlags: *anyopaque,
        GetDeviceRemovedReason: *anyopaque,
        GetImmediateContext: *anyopaque,
        SetExceptionMode: *anyopaque,
        GetExceptionMode: *anyopaque,
    };
};

pub const ID3D11Resource = extern struct {
    __v: *const VTable,

    pub const VTable = extern struct {
        base: ID3D11DeviceChild.VTable,
        GetType: *anyopaque,
        SetEvictionPriority: *anyopaque,
        GetEvictionPriority: *anyopaque,
    };
};

pub const ID3D11DeviceChild = extern struct {
    __v: *const VTable,

    pub const VTable = extern struct {
        base: IUnknown.VTable,
        GetDevice: *anyopaque,
        GetPrivateData: *anyopaque,
        SetPrivateData: *anyopaque,
        SetPrivateDataInterface: *anyopaque,
    };
};

pub const ID3D11RenderTargetView = extern struct {
    __v: *const VTable,
    Unknown: IUnknown.Mixin(@This()) = .{},

    pub const VTable = extern struct {
        base: ID3D11View.VTable,
        GetDesc: *anyopaque,
    };
};

pub const ID3D11View = extern struct {
    __v: *const VTable,

    pub const VTable = extern struct {
        base: ID3D11DeviceChild.VTable,
        GetResource: *anyopaque,
    };
};

pub const ID3D11DeviceContext = extern struct {
    __v: *const VTable,

    DeviceContext: Mixin(@This()),
    Unknown: IUnknown.Mixin(@This()),

    pub fn Mixin(comptime T: type) type {
        return struct {
            pub fn OMSetRenderTargets(
                m: *@This(),
                NumViews: w32.UINT,
                ppRenderTargetViews: ?[*]const *ID3D11RenderTargetView,
                pDepthStencilView: ?*anyopaque,
            ) void {
                const self: *T = @alignCast(@fieldParentPtr("DeviceContext", m));
                const vt: *const ID3D11DeviceContext.VTable = @ptrCast(self.__v);
                const ctx: *ID3D11DeviceContext = @ptrCast(self);
                return vt.OMSetRenderTargets(
                    ctx,
                    NumViews,
                    ppRenderTargetViews,
                    pDepthStencilView,
                );
            }

            pub inline fn ClearRenderTargetView(
                m: *@This(),
                pRenderTargetView: *ID3D11RenderTargetView,
                ColorRGBA: *const [4]w32.FLOAT,
            ) void {
                const self: *T = @alignCast(@fieldParentPtr("DeviceContext", m));
                const vt: *const ID3D11DeviceContext.VTable = @ptrCast(self.__v);
                const ctx: *ID3D11DeviceContext = @ptrCast(self);
                return vt.ClearRenderTargetView(
                    ctx,
                    pRenderTargetView,
                    ColorRGBA,
                );
            }
        };
    }

    pub const VTable = extern struct {
        const T = ID3D11DeviceContext;
        base: ID3D11DeviceChild.VTable,
        VSSetConstantBuffers: *anyopaque,
        PSSetShaderResources: *anyopaque,
        PSSetShader: *anyopaque,
        PSSetSamplers: *anyopaque,
        VSSetShader: *anyopaque,
        DrawIndexed: *anyopaque,
        Draw: *anyopaque,
        Map: *anyopaque,
        Unmap: *anyopaque,
        PSSetConstantBuffers: *anyopaque,
        IASetInputLayout: *anyopaque,
        IASetVertexBuffers: *anyopaque,
        IASetIndexBuffer: *anyopaque,
        DrawIndexedInstanced: *anyopaque,
        DrawInstanced: *anyopaque,
        GSSetConstantBuffers: *anyopaque,
        GSSetShader: *anyopaque,
        IASetPrimitiveTopology: *anyopaque,
        VSSetShaderResources: *anyopaque,
        VSSetSamplers: *anyopaque,
        Begin: *anyopaque,
        End: *anyopaque,
        GetData: *anyopaque,
        SetPredication: *anyopaque,
        GSSetShaderResources: *anyopaque,
        GSSetSamplers: *anyopaque,
        OMSetRenderTargets: *const fn (
            *T,
            w32.UINT,
            ?[*]const *ID3D11RenderTargetView,
            ?*anyopaque,
        ) callconv(WINAPI) void,
        OMSetRenderTargetsAndUnorderedAccessViews: *anyopaque,
        OMSetBlendState: *anyopaque,
        OMSetDepthStencilState: *anyopaque,
        SOSetTargets: *anyopaque,
        DrawAuto: *anyopaque,
        DrawIndexedInstancedIndirect: *anyopaque,
        DrawInstancedIndirect: *anyopaque,
        Dispatch: *anyopaque,
        DispatchIndirect: *anyopaque,
        RSSetState: *anyopaque,
        RSSetViewports: *anyopaque,
        RSSetScissorRects: *anyopaque,
        CopySubresourceRegion: *anyopaque,
        CopyResource: *anyopaque,
        UpdateSubresource: *anyopaque,
        CopyStructureCount: *anyopaque,
        ClearRenderTargetView: *const fn (*T, *ID3D11RenderTargetView, *const [4]w32.FLOAT) callconv(WINAPI) void,
        ClearUnorderedAccessViewUint: *anyopaque,
        ClearUnorderedAccessViewFloat: *anyopaque,
        ClearDepthStencilView: *anyopaque,
        GenerateMips: *anyopaque,
        SetResourceMinLOD: *anyopaque,
        GetResourceMinLOD: *anyopaque,
        ResolveSubresource: *anyopaque,
        ExecuteCommandList: *anyopaque,
        HSSetShaderResources: *anyopaque,
        HSSetShader: *anyopaque,
        HSSetSamplers: *anyopaque,
        HSSetConstantBuffers: *anyopaque,
        DSSetShaderResources: *anyopaque,
        DSSetShader: *anyopaque,
        DSSetSamplers: *anyopaque,
        DSSetConstantBuffers: *anyopaque,
        CSSetShaderResources: *anyopaque,
        CSSetUnorderedAccessViews: *anyopaque,
        CSSetShader: *anyopaque,
        CSSetSamplers: *anyopaque,
        CSSetConstantBuffers: *anyopaque,
        VSGetConstantBuffers: *anyopaque,
        PSGetShaderResources: *anyopaque,
        PSGetShader: *anyopaque,
        PSGetSamplers: *anyopaque,
        VSGetShader: *anyopaque,
        PSGetConstantBuffers: *anyopaque,
        IAGetInputLayout: *anyopaque,
        IAGetVertexBuffers: *anyopaque,
        IAGetIndexBuffer: *anyopaque,
        GSGetConstantBuffers: *anyopaque,
        GSGetShader: *anyopaque,
        IAGetPrimitiveTopology: *anyopaque,
        VSGetShaderResources: *anyopaque,
        VSGetSamplers: *anyopaque,
        GetPredication: *anyopaque,
        GSGetShaderResources: *anyopaque,
        GSGetSamplers: *anyopaque,
        OMGetRenderTargets: *anyopaque,
        OMGetRenderTargetsAndUnorderedAccessViews: *anyopaque,
        OMGetBlendState: *anyopaque,
        OMGetDepthStencilState: *anyopaque,
        SOGetTargets: *anyopaque,
        RSGetState: *anyopaque,
        RSGetViewports: *anyopaque,
        RSGetScissorRects: *anyopaque,
        HSGetShaderResources: *anyopaque,
        HSGetShader: *anyopaque,
        HSGetSamplers: *anyopaque,
        HSGetConstantBuffers: *anyopaque,
        DSGetShaderResources: *anyopaque,
        DSGetShader: *anyopaque,
        DSGetSamplers: *anyopaque,
        DSGetConstantBuffers: *anyopaque,
        CSGetShaderResources: *anyopaque,
        CSGetUnorderedAccessViews: *anyopaque,
        CSGetShader: *anyopaque,
        CSGetSamplers: *anyopaque,
        CSGetConstantBuffers: *anyopaque,
        ClearState: *anyopaque,
        Flush: *anyopaque,
        GetType: *anyopaque,
        GetContextFlags: *anyopaque,
        FinishCommandList: *anyopaque,
    };
};

pub const ID3D11Texture2D = extern struct {
    __v: *const VTable,
    Unknown: IUnknown.Mixin(@This()) = .{},

    pub const IID = w32.GUID.parse("{6f15aaf2-d208-4e89-9ab4-489535d34f9c}");
    pub const VTable = extern struct {
        base: ID3D11Resource.VTable,
        GetDesc: *anyopaque,
    };
};

const WINAPI = std.builtin.CallingConvention.winapi;
const WNDPROC = *const fn (hwnd: w32.HWND, msg: w32.UINT, wparam: w32.WPARAM, lparam: w32.LPARAM) callconv(WINAPI) w32.LRESULT;
