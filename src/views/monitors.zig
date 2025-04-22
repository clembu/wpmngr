const std = @import("std");
const vec = @import("../vec.zig");
const Db = @import("../db/db.zig");
// TODO: bindings get their own Import Modules?
const imgui = @import("../bindings/imgui.zig");

edit_mode: ?EditMode,
// monitors: []Db.Monitor,
// TODO: editor is for ONE monitor
// TODO: selectable tile
// -> custom rendering (drawlist)
// Use empty-text selectable for the frame

pub const init: @This() = .{
    .edit_mode = null,
};

pub const EditMode = union(enum) {
    new: struct {
        name_buf: [255:0]u8,
        asp_width: u32,
        asp_height: u32,
        min_width: u32,
        min_height: u32,
    },
    rename: struct {
        name_buf: [255:0]u8,
        idx: usize,
    },
};

// TODO: return message instead of sending it?
pub fn draw(
    self: *@This(),
    allocator: std.mem.Allocator,
    monitors: []Db.Monitor,
) !void {
    defer imgui.window.end();
    if (!imgui.window.begin("Monitors", .{})) return;

    const win_dims = imgui.cursor.getContentRegionAvail();

    var columns = @divFloor(win_dims[0], 150);
    if (columns < 1) columns = 1;

    const column_width = win_dims[0] / columns;
    const preview_height = 100.0;

    const tile_width = column_width - 2 * imgui.getStyle().framePadding[0];
    const tile_height = preview_height + imgui.layout.lineHeightWithSpacing() * 2 + imgui.layout.frameHeightWithSpacing();

    for (monitors, 0..) |mon, idx| {
        const col: u32 = @as(u32, @intCast(idx)) % @as(u32, @intFromFloat(columns));
        if (col == 0) imgui.layout.newLine() else imgui.layout.sameLine(.{});

        var cur = imgui.cursor.getScreenPos();
        const h_center = @mulAdd(f32, tile_width, 0.5, cur[0]);

        imgui.ids.pushUSize(idx);
        defer imgui.ids.pop();
        imgui.group.begin();
        defer imgui.group.end();
        imgui.layout.dummy(.{ tile_width, tile_height });

        // Name
        {
            const txt_size = imgui.text.calcRawSize(mon.name[0..], .{});
            const pos = .{
                @mulAdd(f32, -0.5, txt_size[0], h_center),
                cur[1],
            };
            try imgui.window.getDrawList().addFormattedText("{s}", .{mon.name}, pos, 0xffffffff);
            cur[1] += imgui.layout.lineHeightWithSpacing();
        }
        // Preview
        {
            const avail: vec.V2 = .{ tile_width, preview_height };
            const scr_size = vec.fit(
                .{ @floatFromInt(mon.width), @floatFromInt(mon.height) },
                avail,
            );
            const center: vec.V2 = @mulAdd(vec.V2, avail, @splat(0.5), cur);
            imgui.window.getDrawList().addRect(
                @mulAdd(vec.V2, @splat(-0.5), scr_size, center),
                @mulAdd(vec.V2, @splat(0.5), scr_size, center),
                0xffffffff,
                .{},
            );
            cur[1] += preview_height + imgui.getStyle().itemSpacing[1];
        }
        // Size
        {
            const txt_size = try imgui.text.calcFormattedSize(
                "{d} x {d}",
                .{ mon.width, mon.height },
                .{},
            );
            const pos = .{
                @mulAdd(f32, -0.5, txt_size[0], h_center),
                cur[1],
            };
            try imgui.window.getDrawList().addFormattedText(
                "{d} x {d}",
                .{ mon.width, mon.height },
                pos,
                0xffffffff,
            );
        }
        if (imgui.button(
            "Delete",
            .{ .size = .{ @mulAdd(f32, tile_width, 0.5, -(imgui.getStyle().itemSpacing[0])), 0 } },
        )) {
            imgui.popup.open("Delete?", .{});
        }
        imgui.layout.sameLine(.{});
        if (imgui.button(
            "Rename",
            .{ .size = .{ @mulAdd(f32, tile_width, 0.5, -(imgui.getStyle().itemSpacing[0])), 0 } },
        )) {
            self.edit_mode = .{ .rename = .{
                .name_buf = @splat(0),
                .idx = idx,
            } };
            std.mem.copyForwards(u8, &self.edit_mode.?.rename.name_buf, mon.name);
        }

        if (imgui.popup.beginModal("Delete?", .{ .flags = .{ .AlwaysAutoResize = true } })) {
            defer imgui.popup.end();
            try imgui.text.formatted("Delete monitor {s}?", .{mon.name});
            imgui.text.raw("It will delete all wallpapers registered for it");
            if (imgui.button("Yes", .{ .size = .{ 120, 0 } })) {
                _ = self.req(.{ .delete = mon.id });
                imgui.popup.close();
                self.edit_mode = null;
            }
            imgui.layout.sameLine(.{});
            if (imgui.button("No", .{ .size = .{ 120, 0 } })) {
                imgui.popup.close();
                self.edit_mode = null;
            }
        }
    }
    imgui.separator(.{});
    if (self.edit_mode) |*mode| {
        switch (mode.*) {
            .new => |*info| {
                _ = imgui.input.text("Name", &info.name_buf, .{});
                {
                    imgui.text.raw("Aspect");
                    imgui.layout.indent(.{});
                    defer imgui.layout.unindent(.{});
                    if (imgui.dragInt("Width##Aspect", &info.asp_width, .{ .min = 1 })) {
                        info.min_width = info.min_height / info.asp_height * info.asp_width;
                    }
                    if (imgui.dragInt("Height##Aspect", &info.asp_height, .{ .min = 1 })) {
                        info.min_height = info.min_width / info.asp_width * info.asp_height;
                    }
                }
                {
                    imgui.text.raw("Minimum size");
                    imgui.layout.indent(.{});
                    defer imgui.layout.unindent(.{});
                    if (imgui.dragInt("Width##Size", &info.min_width, .{
                        .speed = @floatFromInt(info.asp_width),
                    })) {
                        info.min_height = info.min_width / info.asp_width * info.asp_height;
                    }
                    if (imgui.dragInt("Height##Size", &info.min_height, .{
                        .speed = @floatFromInt(info.asp_height),
                    })) {
                        info.min_width = info.min_height / info.asp_height * info.asp_width;
                    }
                }

                if (imgui.button("OK", .{})) {
                    _ = self.req(.{ .new = .{
                        .name_buf = info.name_buf,
                        .width = info.min_width,
                        .height = info.min_height,
                    } });
                    self.edit_mode = null;
                }
                imgui.layout.sameLine(.{});
                if (imgui.button("Cancel", .{})) {
                    self.edit_mode = null;
                }
            },
            .rename => |*info| {
                _ = imgui.input.text("Name", &info.name_buf, .{});
                if (imgui.button("OK", .{})) {
                    _ = self.req(.{ .rename = .{
                        .id = monitors[info.idx].id,
                        .name = info.name_buf,
                    } });

                    allocator.free(monitors[info.idx].name);
                    monitors[info.idx].name = try allocator.dupeZ(
                        u8,
                        std.mem.span(info.name_buf[0..].ptr),
                    );

                    self.edit_mode = null;
                }
                imgui.layout.sameLine(.{});
                if (imgui.button("Cancel", .{})) {
                    self.edit_mode = null;
                }
            },
        }
    } else if (imgui.button("Add", .{})) {
        self.edit_mode = .{ .new = .{
            .name_buf = @splat(0),
            .asp_width = 16,
            .asp_height = 9,
            .min_width = 1920,
            .min_height = 1080,
        } };
        std.mem.copyForwards(u8, &self.edit_mode.?.new.name_buf, "New Monitor");
    }
}

pub fn req(self: *@This(), msg: WorkMsg) bool {
    const app: *@import("../app.zig") = @alignCast(@fieldParentPtr("monitors_window", self));
    return app.req.send(.{ .monitors = msg });
}

pub const WorkMsg = union(enum) {
    delete: u64,
    new: struct {
        name_buf: [255:0]u8,
        width: u32,
        height: u32,
    },
    rename: struct {
        id: u64,
        name: [255:0]u8,
    },
};
