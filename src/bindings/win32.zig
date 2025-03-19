const w32 = @import("std").os.windows;

pub const UINT = w32.UINT;
pub const LPCSTR = w32.LPCSTR;
pub const LPCWSTR = w32.LPCWSTR;
pub const DWORD = w32.DWORD;
pub const WPARAM = w32.WPARAM;
pub const LPARAM = w32.LPARAM;
pub const HWND = w32.HWND;
pub const HMODULE = w32.HMODULE;
pub const HRESULT = w32.HRESULT;
pub const HRESULT_CODE = w32.HRESULT_CODE;
pub const LRESULT = w32.LRESULT;
pub const LONG_PTR = w32.LONG_PTR;
pub const RECT = w32.RECT;
pub const BOOL = w32.BOOL;
pub const FLOAT = w32.FLOAT;
pub const GUID = w32.GUID;
pub const TRUE = w32.TRUE;
pub const FALSE = w32.FALSE;
pub const S_OK = w32.S_OK;

pub const PATH_MAX_WIDE = w32.PATH_MAX_WIDE;

pub const WNDCLASSEXA = extern struct {
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

pub const MSG = extern struct {
    hWnd: ?w32.HWND,
    message: w32.UINT,
    wParam: w32.WPARAM,
    lParam: w32.LPARAM,
    time: w32.DWORD,
    pt: w32.POINT,
    lPrivate: w32.DWORD,
};

pub extern "user32" fn DefWindowProcA(hwnd: w32.HWND, msg: w32.UINT, wparam: w32.WPARAM, lparam: w32.LPARAM) callconv(WINAPI) w32.LRESULT;
pub extern "user32" fn CreateWindowExA(dwExStyle: w32.DWORD, lpClassName: ?w32.LPCSTR, lpWindowName: ?w32.LPCSTR, dwStyle: w32.DWORD, X: c_int, Y: c_int, nWidth: c_int, nHeight: c_int, hWindParent: ?w32.HWND, hMenu: ?w32.HMENU, hInstance: w32.HINSTANCE, lpParam: ?w32.LPVOID) callconv(WINAPI) ?w32.HWND;
pub extern "user32" fn RegisterClassExA(*const WNDCLASSEXA) callconv(WINAPI) w32.ATOM;
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

pub extern "ole32" fn CoInitializeEx(?*anyopaque, w32.DWORD) callconv(WINAPI) w32.HRESULT;
pub extern "ole32" fn CoUninitialize() callconv(WINAPI) w32.HRESULT;
pub extern "ole32" fn CoCreateInstance(rclsid: *const w32.GUID, pUnkOuter: ?*IUnknown, dwClsContext: w32.DWORD, riid: *const w32.GUID, ppv: *?*anyopaque) callconv(WINAPI) w32.HRESULT;
pub const CLSCTX_INPROC_SERVER : w32.DWORD = 0x1;

pub const WS_OVERLAPPED: w32.DWORD = 0x0000_0000;
pub const WS_CAPTION: w32.DWORD = 0x00C0_0000;
pub const WS_SYSMENU: w32.DWORD = 0x0008_0000;
pub const WS_THICKFRAME: w32.DWORD = 0x0004_0000;
pub const WS_MINIMIZEBOX: w32.DWORD = 0x0002_0000;
pub const WS_MAXIMIZEBOX: w32.DWORD = 0x0001_0000;
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
        Release: *const fn (*IUnknown) callconv(.winapi) w32.ULONG,
    };
};
