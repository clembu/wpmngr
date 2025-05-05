const std = @import("std");
const w32 = std.os.windows;

pub const UINT = w32.UINT;
pub const LPCSTR = w32.LPCSTR;
pub const LPCWSTR = w32.LPCWSTR;
pub const DWORD = w32.DWORD;
pub const WPARAM = w32.WPARAM;
pub const LPARAM = w32.LPARAM;
pub const HWND = w32.HWND;
pub const HINSTANCE = w32.HINSTANCE;
pub const HMODULE = w32.HMODULE;
pub const HRESULT = w32.HRESULT;
pub const HRESULT_CODE = w32.HRESULT_CODE;
pub const LRESULT = w32.LRESULT;
pub const LONG_PTR = w32.LONG_PTR;
pub const RECT = w32.RECT;
pub const BOOL = w32.BOOL;
pub const FLOAT = w32.FLOAT;
pub const WCHAR = w32.WCHAR;
pub const GUID = w32.GUID;
pub const TRUE = w32.TRUE;
pub const FALSE = w32.FALSE;
pub const S_OK = w32.S_OK;
pub const E_NOINTERFACE = w32.E_NOINTERFACE;

pub fn SUCCEEDED(hr: HRESULT) bool {
    return hr >= 0;
}

pub const HMENU = w32.HMENU;
pub const HMONITOR = w32.HANDLE;

pub const PATH_MAX_WIDE = w32.PATH_MAX_WIDE;

pub const WNDCLASSEXA = extern struct {
    cbSize: w32.UINT = @sizeOf(WNDCLASSEXA),
    style: w32.UINT = 0,
    lpfnWndProc: WNDPROC,
    cbClsExtra: i32 = 0,
    cbWndExtra: i32 = 0,
    hInstance: ?w32.HINSTANCE = null,
    hIcon: ?w32.HICON = null,
    hCursor: ?w32.HCURSOR = null,
    hbrBackground: ?w32.HBRUSH = null,
    lpszMenuName: ?w32.LPCSTR = null,
    lpszClassName: w32.LPCSTR,
    hIconSm: ?w32.HICON = null,
};

pub fn registerClass(wcl: WNDCLASSEXA) void {
    _ = RegisterClassExA(&wcl);
}
pub extern "user32" fn RegisterClassExA(*const WNDCLASSEXA) callconv(WINAPI) w32.ATOM;

pub const MSG = extern struct {
    hWnd: ?w32.HWND,
    message: w32.UINT,
    wParam: w32.WPARAM,
    lParam: w32.LPARAM,
    time: w32.DWORD,
    pt: w32.POINT,
    lPrivate: w32.DWORD,
};

pub const WinStyle = packed struct(u32) {
    _: u16 = 0,                  // WS_OVERLAPPED   0x00000000
    maximize_box: bool = false,  // WS_MAXIMIZEBOX  0x00010000
    minimize_box: bool = false,  // WS_MINIMIZEBOX  0x00020000
    thick_frame: bool = false,   // WS_THICKFRAME   0x00040000
    sys_menu: bool = false,      // WS_SYSMENU      0x00080000
    scroll_h: bool = false,      // WS_HSCROLL      0x00100000
    scroll_v: bool = false,      // WS_VSCROLL      0x00200000
    dialog_frame: bool = false,  // WS_DLGFRAME     0x00400000
    border: bool = false,        // WS_BORDER       0x00800000
    maximize: bool = false,      // WS_MAXIMIZE     0x01000000
    clip_children: bool = false, // WS_CLIPCHILDREN 0x02000000
    clip_siblings: bool = false, // WS_CLIPSIBLINGS 0x04000000
    disabled: bool = false,      // WS_DISABLED     0x08000000
    visible: bool = false,       // WS_VISIBLE      0x10000000
    minimize: bool = false,      // WS_MINIMIZE     0x20000000
    child: bool = false,         // WS_CHILD        0x40000000
    popup: bool = false,         // WS_POPUP        0x80000000

    pub const overlapped_window: WinStyle = .{
        .border = true,
        .dialog_frame = true,
        .sys_menu = true,
        .thick_frame = true,
        .minimize_box = true,
    };

    pub inline fn with(a: WinStyle, b: WinStyle) WinStyle {
        return .{
            .maximize_box = a.maximize_box or b.maximize_box,
            .minimize_box = a.minimize_box or b.minimize_box,
            .thick_frame = a.thick_frame or b.thick_frame,
            .sys_menu = a.sys_menu or b.sys_menu,
            .scroll_h = a.scroll_h or b.scroll_h,
            .scroll_v = a.scroll_v or b.scroll_v,
            .dialog_frame = a.dialog_frame or b.dialog_frame,
            .border = a.border or b.border,
            .maximize = a.maximize or b.maximize,
            .clip_children = a.clip_children or b.clip_children,
            .clip_siblings = a.clip_siblings or b.clip_siblings,
            .disabled = a.disabled or b.disabled,
            .visible = a.visible or b.visible,
            .minimize = a.minimize or b.minimize,
            .child = a.child or b.child,
            .popup = a.popup or b.popup,
        };
    }
};

pub fn createWindow(className: [:0]const u8, title: [:0]const u8, opts: struct {
    exStyle: DWORD = 0,
    style: WinStyle = .{},
    posx: c_int = CW_USEDEFAULT,
    posy: c_int = CW_USEDEFAULT,
    width: c_int = CW_USEDEFAULT,
    height: c_int = CW_USEDEFAULT,
    parent: ?HWND = null,
    menu: ?HMENU = null,
    hInstance: ?HINSTANCE = null,
    param: ?*anyopaque = null,
}) !HWND {
    if (CreateWindowExA(
        opts.exStyle,
        className,
        title,
        opts.style,
        opts.posx,
        opts.posy,
        opts.width,
        opts.height,
        opts.parent,
        opts.menu,
        opts.hInstance,
        opts.param,
    )) |hwnd| {
        return hwnd;
    } else {
        return error.CreateWindow;
    }
}
pub extern "user32" fn CreateWindowExA(dwExStyle: w32.DWORD, lpClassName: ?w32.LPCSTR, lpWindowName: ?w32.LPCSTR, dwStyle: WinStyle, X: c_int, Y: c_int, nWidth: c_int, nHeight: c_int, hWindParent: ?w32.HWND, hMenu: ?w32.HMENU, hInstance: ?w32.HINSTANCE, lpParam: ?w32.LPVOID) callconv(WINAPI) ?w32.HWND;

pub extern "user32" fn DefWindowProcA(hwnd: w32.HWND, msg: w32.UINT, wparam: w32.WPARAM, lparam: w32.LPARAM) callconv(WINAPI) w32.LRESULT;

pub inline fn destroyWindow(hwnd: HWND) void {
    _ = DestroyWindow(hwnd);
}
pub extern "user32" fn DestroyWindow(w32.HWND) callconv(WINAPI) w32.BOOL;

pub fn getExeHInstance() HINSTANCE {
    return @ptrCast(GetModuleHandleA(null).?);
}
pub extern "kernel32" fn GetModuleHandleA(lpModuleName: ?w32.LPCSTR) callconv(WINAPI) ?w32.HMODULE;

pub extern "user32" fn GetClientRect(w32.HWND, *w32.RECT) w32.BOOL;

extern "user32" fn SetWindowLongPtrA(w32.HWND, c_int, w32.LONG_PTR) w32.LONG_PTR;
extern "user32" fn GetWindowLongPtrA(w32.HWND, c_int) w32.LONG_PTR;
const GWLP_USERDATA = -21;

pub fn setWindowUserData(hwnd: w32.HWND, data: ?*anyopaque) ?*anyopaque {
    const lpData: w32.LONG_PTR = @bitCast(@intFromPtr(data));
    const r = SetWindowLongPtrA(hwnd, GWLP_USERDATA, lpData);
    const ru: usize = @bitCast(r);
    return @ptrFromInt(ru);
}

pub fn getWindowUserData(comptime T: type, hwnd: w32.HWND) ?*T {
    const r = GetWindowLongPtrA(hwnd, GWLP_USERDATA);
    const ru: usize = @bitCast(r);
    return @ptrFromInt(ru);
}

pub extern "user32" fn LoadCursorA(hInstance: ?w32.HINSTANCE, lpCursorName: ?w32.LPCSTR) callconv(WINAPI) ?w32.HCURSOR;

pub extern "user32" fn PeekMessageA(lpMsg: *const MSG, hWnd: ?w32.HWND, wMsgFilterMin: w32.UINT, wMsgFilterMax: w32.UINT, wRemoveMsg: w32.UINT) callconv(WINAPI) w32.BOOL;
pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(WINAPI) w32.BOOL;
pub extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(WINAPI) w32.LRESULT;
pub extern "user32" fn PostQuitMessage(i32) callconv(WINAPI) void;

/// Component-Object Model
pub const com = struct {
    pub inline fn init(opts: InitOpts) !void {
        const hr = CoInitializeEx(null, @bitCast(opts));
        if (!SUCCEEDED(hr)) {
            switch (hr) {
                w32.E_INVALIDARG => return error.InvalidArg,
                w32.E_OUTOFMEMORY => return error.OutOfMemory,
                @as(i32, @bitCast(@as(u32, 0x80010106))) => return error.RpcChangedMode,
                else => return error.Unexpected,
            }
        }
    }
    pub extern "ole32" fn CoInitializeEx(?*anyopaque, w32.DWORD) callconv(WINAPI) w32.HRESULT;

    pub const InitOpts = packed struct(u32) {
        threading: Threading = .multi,
        disable_ole1_dde: bool = false,
        speed_over_memory: bool = false,
        _: u28 = 0,

        pub const Threading = enum(u2) {
            multi = 0,
            apartment = 2,
        };
    };

    pub inline fn deinit() void {
        CoUninitialize();
    }
    pub extern "ole32" fn CoUninitialize() callconv(WINAPI) void;

    /// Assumes the given type has the following GUID declarations available:
    /// `IID`: The Interface ID of the requested type.
    pub fn create(comptime ITF: type, clsid: *const GUID) !*ITF {
        var res: ?*ITF = null;
        const hr = CoCreateInstance(clsid, null, CLSCTX_INPROC_SERVER, &ITF.IID, @ptrCast(&res));
        if (!SUCCEEDED(hr)) {
            return error.CoInstanceError;
        }
        return res.?;
    }
    pub extern "ole32" fn CoCreateInstance(rclsid: *const w32.GUID, pUnkOuter: ?*IUnknown, dwClsContext: w32.DWORD, riid: *const w32.GUID, ppv: *?*anyopaque) callconv(WINAPI) w32.HRESULT;
};

pub const CLSCTX_INPROC_SERVER: w32.DWORD = 0x1;

pub const WS_OVERLAPPED: w32.DWORD = 0x0000_0000;
pub const WS_CAPTION: w32.DWORD = 0x00C0_0000;
pub const WS_SYSMENU: w32.DWORD = 0x0008_0000;
pub const WS_THICKFRAME: w32.DWORD = 0x0004_0000;
pub const WS_MINIMIZEBOX: w32.DWORD = 0x0002_0000;
pub const WS_MAXIMIZEBOX: w32.DWORD = 0x0001_0000;
pub const WS_MAXIMIZE: w32.DWORD = 0x0100_0000;
pub const WS_OVERLAPPEDWINDOW: w32.DWORD =
    WS_OVERLAPPED | WS_CAPTION |
    WS_SYSMENU | WS_THICKFRAME |
    WS_MINIMIZEBOX | WS_MAXIMIZEBOX;
pub const WS_VISIBLE: w32.DWORD = 0x1000_0000;

// NOTE: undocumented value, taken from available SDK source
// in winuser.h
pub const CW_USEDEFAULT = @as(i32, @bitCast(@as(u32, 0x80000000)));
pub const IDC_ARROW: w32.LPCSTR = @ptrFromInt(32512);

pub const PM_REMOVE: w32.UINT = 0x0001;

pub const WM_QUIT: w32.UINT = 0x0012;
pub const WM_DESTROY: w32.UINT = 0x0002;
pub const WM_CLOSE: w32.UINT = 0x0010;
pub const WM_SIZE: w32.UINT = 0x0005;
pub const WM_SIZING: w32.UINT = 0x0214;

pub const WINAPI = @import("std").builtin.CallingConvention.winapi;
pub const WNDPROC = *const fn (hwnd: w32.HWND, msg: w32.UINT, wparam: w32.WPARAM, lparam: w32.LPARAM) callconv(WINAPI) w32.LRESULT;

// Interfaces

pub const IUnknown = extern struct {
    __v: *const VTable,

    Unknown: Mixin(@This()) = .{},

    pub fn Mixin(comptime T: type) type {
        return struct {
            pub inline fn QueryInterface(m: *@This(), comptime I: type) !*I {
                const self: *T = @alignCast(@fieldParentPtr("Unknown", m));
                const vt: *const IUnknown.VTable = @ptrCast(self.__v);
                const ctx: *IUnknown = @ptrCast(self);
                var ptr: ?*I = null;
                const hr = vt.QueryInterface(ctx, I.IID, @ptrCast(&ptr));
                switch (hr) {
                    S_OK => return ptr.?,
                    E_NOINTERFACE => return error.NoInterface,
                    else => unreachable,
                }
            }

            pub inline fn Release(m: *@This()) w32.ULONG {
                const self: *T = @alignCast(@fieldParentPtr("Unknown", m));
                const vt: *const IUnknown.VTable = @ptrCast(self.__v);
                const ctx: *IUnknown = @ptrCast(self);
                return vt.Release(ctx);
            }
        };
    }

    pub const VTable = extern struct {
        QueryInterface: *const fn (*IUnknown, GUID, ?*?*anyopaque) callconv(.winapi) HRESULT,
        AddRef: *anyopaque,
        Release: *const fn (*IUnknown) callconv(.winapi) w32.ULONG,
    };
};
