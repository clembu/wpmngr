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
    _ = CreateWindowExA(
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
    mainloop: while (true) {
        // A: Dispatch messages, quit if we receive a QUIT.
        var msg = std.mem.zeroes(MSG);
        while (PeekMessageA(&msg, null, 0, 0, PM_REMOVE) == w32.TRUE) {
            _ = TranslateMessage(&msg);
            _ = DispatchMessageA(&msg);
            if (msg.message == WM_QUIT) {
                break :mainloop;
            }
        }
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
        else => {}
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

const WM_QUIT : w32.UINT = 0x0012;
const WM_DESTROY : w32.UINT = 0x0002;
const WM_CLOSE : w32.UINT = 0x0010;

const WINAPI = std.builtin.CallingConvention.winapi;
const WNDPROC = *const fn (hwnd: w32.HWND, msg: w32.UINT, wparam: w32.WPARAM, lparam: w32.LPARAM) callconv(WINAPI) w32.LRESULT;
