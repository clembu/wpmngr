const std = @import("std");
const imgui = @import("bindings/imgui.zig");

pub fn update() void {
    imgui.showDemoWindow();
}
