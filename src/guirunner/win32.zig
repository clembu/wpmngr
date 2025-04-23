const dx = @import("../bindings/directx.zig");
const w32 = @import("../bindings/win32.zig");
const imgui = @import("../bindings/imgui.zig");
const std = @import("std");
const root = @import("root");

hwnd: w32.HWND,
gui: root.Gui,

const MAIN_WINDOW_CLASS = "WPMNGR";

pub fn init(params: root.Gui.CreationParameters) !@This() {
    try w32.com.init(.{});
    errdefer w32.com.deinit();

    const hinst: w32.HINSTANCE = w32.getExeHInstance();

    w32.registerClass(.{
        .lpfnWndProc = wndProc,
        .hInstance = hinst,
        .hCursor = w32.LoadCursorA(null, w32.IDC_ARROW),
        .lpszClassName = MAIN_WINDOW_CLASS,
    });
    const hwnd = try w32.createWindow(MAIN_WINDOW_CLASS, "WPMNGR", .{
        .style = w32.WinStyle.overlapped_window.with(.{ .visible = true, .maximize = true }),
        .hInstance = hinst,
    });
    errdefer w32.destroyWindow(hwnd);

    const rt: root.GuiRT = try .init(params.allocator, hwnd);
    errdefer rt.deinit();
    const gui: root.Gui = .init(rt, params);

    return .{
        .hwnd = hwnd,
        .gui = gui,
    };
}

pub fn deinit(self: *@This()) void {
    self.gui.deinit();
    w32.com.deinit();
}

pub fn run(self: *@This()) !void {
    _ = w32.setWindowUserData(self.hwnd, self);
    mainloop: while (true) {
        var msg = std.mem.zeroes(w32.MSG);
        while (w32.PeekMessageA(&msg, null, 0, 0, w32.PM_REMOVE) == w32.TRUE) {
            _ = w32.TranslateMessage(&msg);
            _ = w32.DispatchMessageA(&msg);
            if (msg.message == w32.WM_QUIT) {
                break :mainloop;
            }
        }
        try self.paint();
    }

    while (!self.gui.mbx.work.send(.quit)) {
        std.Thread.yield() catch {};
    }
}

pub fn paint(self: *@This()) !void {
    imgui.newFrame();

    if (self.gui.mbx.gui.receive()) |msg| {
        try self.gui.handle_msg(msg);
    }

    try self.gui.update();

    self.gui.rt.devctx.DeviceContext.OMSetRenderTargets(1, &.{self.gui.rt.mainRTV}, null);
    self.gui.rt.devctx.DeviceContext.ClearRenderTargetView(self.gui.rt.mainRTV, &.{ 0.45, 0.55, 0.60, 1.00 });

    imgui.render();

    _ = self.gui.rt.sc.SwapChain.Present(1, .{});
}

pub fn resize(self: *@This(), width: u32, height: u32) void {
    self.gui.rt.devctx.DeviceContext.OMSetRenderTargets(0, null, null);
    _ = self.gui.rt.mainRTV.Unknown.Release();
    self.gui.rt.devctx.DeviceContext.Flush();
    _ = self.gui.rt.sc.SwapChain.ResizeBuffers(1, width, height, .UNKNOWN, .{});
    const backbfr = self.gui.rt.sc.SwapChain.GetBuffer(
        dx.ID3D11Texture2D,
        0,
    ) catch unreachable;
    defer _ = backbfr.Unknown.Release();
    self.gui.rt.mainRTV = self.gui.rt.dev.Device.CreateRenderTargetView(
        @ptrCast(backbfr),
        null,
    ) catch unreachable;
}

pub fn wndProc(
    hwnd: w32.HWND,
    msg: w32.UINT,
    wparam: w32.WPARAM,
    lparam: w32.LPARAM,
) callconv(.winapi) w32.LRESULT {
    if (imgui.backend.win32.wndProcHandler(hwnd, msg, wparam, lparam) != 0) {
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
            const rtopt: ?*@This() = w32.getWindowUserData(@This(), hwnd);
            if (rtopt) |rt| {
                rt.resize(width, height);
                return 0;
            }
        },
        w32.WM_SIZING => {
            var rect: w32.RECT = undefined;
            _ = w32.GetClientRect(hwnd, &rect);
            const rtopt: ?*@This() = w32.getWindowUserData(@This(), hwnd);
            if (rtopt) |rt| {
                rt.resize(
                    @intCast(rect.right - rect.left),
                    @intCast(rect.bottom - rect.top),
                );
                if (rt.paint()) {} else |err| {
                    std.log.err("paint error: {any}", .{err});
                }
                return 0;
            }
        },
        else => {},
    }
    return w32.DefWindowProcA(hwnd, msg, wparam, lparam);
}
