const w32 = @import("std").os.windows;

pub const UINT = w32.UINT;
pub const LPCSTR = w32.LPCSTR;
pub const DWORD = w32.DWORD;
pub const WPARAM = w32.WPARAM;
pub const LPARAM = w32.LPARAM;
pub const HWND = w32.HWND;
pub const HRESULT = w32.HRESULT;
pub const LRESULT = w32.LRESULT;
pub const TRUE = w32.TRUE;
pub const FALSE = w32.FALSE;

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

pub extern "user32" fn LoadCursorA(hInstance: ?w32.HINSTANCE, lpCursorName: ?w32.LPCSTR) callconv(WINAPI) ?w32.HCURSOR;

pub extern "user32" fn PeekMessageA(lpMsg: *const MSG, hWnd: ?w32.HWND, wMsgFilterMin: w32.UINT, wMsgFilterMax: w32.UINT, wRemoveMsg: w32.UINT) callconv(WINAPI) w32.BOOL;
pub extern "user32" fn TranslateMessage(lpMsg: *const MSG) callconv(WINAPI) w32.BOOL;
pub extern "user32" fn DispatchMessageA(lpMsg: *const MSG) callconv(WINAPI) w32.LRESULT;
pub extern "user32" fn PostQuitMessage(i32) callconv(WINAPI) void;

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

pub const WINAPI = @import("std").builtin.CallingConvention.winapi;
pub const WNDPROC = *const fn (hwnd: w32.HWND, msg: w32.UINT, wparam: w32.WPARAM, lparam: w32.LPARAM) callconv(WINAPI) w32.LRESULT;
