const w32 = @import("std").os.windows;

pub fn init(hwnd: w32.HWND) error{ImGuiWin32InitError}!void {
    if (!ImGui_ImplWin32_Init(hwnd)) {
        return error.ImGuiWin32InitError;
    }
}

pub fn deinit() void {
    ImGui_ImplWin32_Shutdown();
}

pub fn newFrame() void {
    ImGui_ImplWin32_NewFrame();
}

pub fn wndProcHandler(
    hwnd: w32.HWND,
    msg: w32.UINT,
    wparam: w32.WPARAM,
    lparam: w32.LPARAM,
) w32.LRESULT {
    return ImGui_ImplWin32_WndProcHandler(hwnd, msg, wparam, lparam);
}

extern fn ImGui_ImplWin32_Init(w32.HWND) bool;
extern fn ImGui_ImplWin32_Shutdown() void;
extern fn ImGui_ImplWin32_NewFrame() void;
extern fn ImGui_ImplWin32_WndProcHandler(w32.HWND, w32.UINT, w32.WPARAM, w32.LPARAM) w32.LRESULT;
