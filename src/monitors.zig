const std = @import("std");
const root = @import("root");
const Db = @import("db/db.zig");
const imgui = @import("bindings/imgui.zig");
const vec = @import("vec.zig");

pub const Display = struct {
    width: u32,
    height: u32,
};

pub const ListWindow = struct {
    originals: []Db.monitors.Monitor,
    items: std.ArrayListUnmanaged(ListItem),
    selected: ?usize,

    pub const ListItem = struct {
        id: ?Db.monitors.ID,
        name_buf: [255:0]u8,
        asp_width: u32,
        asp_height: u32,
        min_width: u32,
        min_height: u32,
        deleted: bool,
        dirty: bool,

        pub inline fn name(self: *const @This()) [:0]const u8 {
            return std.mem.span(self.name_buf[0..].ptr);
        }

        pub fn set_name(self: *@This(), new_name: [:0]const u8) void {
            @memset(&self.name_buf, 0);
            std.mem.copyForwards(u8, &self.name_buf, new_name);
        }
    };

    /// `items` should outlive the window.
    /// If it doesn't, owner should call `reset()` with the new items slice.
    pub fn init(allocator: std.mem.Allocator, items: []Db.monitors.Monitor) !@This() {
        var self: @This() = .{
            .originals = items,
            .items = try .initCapacity(allocator, items.len),
            .selected = null,
        };
        try self.reset(allocator, null);
        return self;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.items.deinit(allocator);
    }

    pub fn reset(
        self: *@This(),
        allocator: std.mem.Allocator,
        items: ?[]Db.monitors.Monitor,
    ) !void {
        self.originals = items orelse self.originals;
        try self.items.resize(allocator, self.originals.len);

        for (self.items.items, self.originals) |*li, *orig| {
            const gcd = std.math.gcd(orig.width, orig.height);
            li.* = .{
                .id = orig.id,
                .name_buf = undefined,
                .min_width = orig.width,
                .min_height = orig.height,
                .asp_width = orig.width / gcd,
                .asp_height = orig.height / gcd,
                .deleted = false,
                .dirty = false,
            };
            li.set_name(orig.name);
        }
    }

    pub fn addOne(self: *@This(), allocator: std.mem.Allocator, width: u32, height: u32) !void {
        const gcd = std.math.gcd(width, height);

        var new = try self.items.addOne(allocator);
        new.* = .{
            .id = null,
            .name_buf = @splat(0),
            .min_width = width,
            .min_height = height,
            .asp_width = width / gcd,
            .asp_height = height / gcd,
            .deleted = false,
            .dirty = true,
        };
        std.mem.copyForwards(u8, &new.name_buf, "New Monitor");
        self.selected = self.items.items.len - 1;
    }

    pub fn master_detail(
        self: *@This(),
        allocator: std.mem.Allocator,
        displays: []Display,
        mbx: *root.Mailbox,
    ) !bool {
        defer imgui.window.end();
        var open = true;
        if (!imgui.window.begin("Monitors", .{ .open = &open, .flags = .{ .MenuBar = true } }))
            return open;

        var added: ?usize = null;
        menu: {
            if (!imgui.menu.bar.begin()) break :menu;
            defer imgui.menu.bar.end();

            if (imgui.menu.begin("Add", .{})) {
                defer imgui.menu.end();
                for (displays) |disp| {
                    var buf: [128]u8 = @splat(0);
                    const label = try std.fmt.bufPrintZ(
                        &buf,
                        "{d} x {d}",
                        .{ disp.width, disp.height },
                    );

                    if (imgui.menu.item(label, .{})) {
                        try self.addOne(allocator, disp.width, disp.height);
                        added = self.items.items.len - 1;
                    }
                }
            }
        }

        const win_dims = imgui.cursor.getContentRegionAvail();

        const Dir = enum { hor, ver };
        const layout_dir: Dir = if (win_dims[0] > win_dims[1]) .hor else .ver;

        var has_deleted = false;
        var has_renamed = false;

        list: {
            const aspect_preview_size = 50.0;
            const tile_content_height = switch (layout_dir) {
                .ver => imgui.layout.lineHeightWithSpacing() +
                    aspect_preview_size +
                    imgui.layout.lineHeightWithSpacing(),
                .hor => aspect_preview_size,
            };
            const tile_height = tile_content_height + 2 * imgui.getStyle().framePadding.y;

            defer imgui.window.endChild();
            if (!imgui.window.beginChild(
                "List",
                .{
                    .size = switch (layout_dir) {
                        .hor => .{ 0, 0 },
                        .ver => .{
                            0,
                            tile_height +
                                2 * imgui.getStyle().windowPadding.y +
                                2 * imgui.getStyle().childBorderSize +
                                imgui.getStyle().scrollbarSize,
                        },
                    },
                    .child_flags = .{
                        .borders = true,
                        .autoResizeX = layout_dir == .hor,
                        .autoResizeY = layout_dir == .ver,
                    },
                    .window_flags = .{
                        .HorizontalScrollbar = layout_dir == .ver,
                    },
                },
            )) {
                break :list;
            }

            for (self.items.items, 0..) |*mon, idx| {
                imgui.ids.pushUSize(idx);
                defer imgui.ids.pop();
                if (layout_dir == .ver and idx > 0) imgui.layout.sameLine(.{});
                imgui.group.begin();
                defer imgui.group.end();

                has_deleted = has_deleted or mon.deleted;
                has_renamed = has_renamed or (mon.dirty and !mon.deleted and (mon.id != null));

                const dirty_indicator = if (mon.dirty) "* " else "";
                const name_format = "{s}{s}";
                const name_width = (try imgui.text.calcFormattedSize(
                    name_format,
                    .{ dirty_indicator, mon.name_buf[0..].ptr },
                    .{},
                ))[0];

                const size_format = "{d} x {d}";
                const size_width = (try imgui.text.calcFormattedSize(
                    size_format,
                    .{ mon.min_width, mon.min_height },
                    .{},
                ))[0];

                const tile_content_width = switch (layout_dir) {
                    .ver => @max(aspect_preview_size, name_width, size_width),
                    .hor => aspect_preview_size +
                        imgui.getStyle().itemInnerSpacing.x +
                        @max(name_width, size_width),
                };

                const tile_width = tile_content_width + 2 * imgui.getStyle().framePadding.x;

                const color = imgui.color.floats_to_u32(if (mon.deleted)
                    imgui.getStyle().colors[@intFromEnum(imgui.Style.Color.textDisabled)]
                else
                    imgui.getStyle().colors[@intFromEnum(imgui.Style.Color.text)]);

                var cur = imgui.cursor.getScreenPos();

                if (imgui.selectable.manual(
                    "##Selection",
                    self.selected == idx,
                    .{ .size = .{ tile_width, tile_height } },
                )) {
                    self.selected = idx;
                }
                if (added == idx) {
                    added = null;
                    switch (layout_dir) {
                        .hor => {
                            imgui.scroll.hereY(.{});
                        },
                        .ver => {
                            imgui.scroll.hereX(.{});
                        },
                    }
                }

                switch (layout_dir) {
                    .ver => {
                        const h_center = @mulAdd(f32, tile_width, 0.5, cur[0]);

                        cur[1] += imgui.getStyle().framePadding.y;

                        // Name
                        {
                            const pos = .{
                                @mulAdd(f32, -0.5, name_width, h_center),
                                cur[1],
                            };
                            try imgui.window.getDrawList().addFormattedText(
                                name_format,
                                .{ dirty_indicator, mon.name_buf[0..].ptr },
                                pos,
                                color,
                            );
                            cur[1] += imgui.layout.lineHeightWithSpacing();
                        }
                        // Preview
                        {
                            const avail: vec.V2 = @splat(aspect_preview_size);
                            const scr_size = vec.fit(
                                .{ @floatFromInt(mon.asp_width), @floatFromInt(mon.asp_height) },
                                avail,
                            );
                            const center: vec.V2 = @mulAdd(
                                vec.V2,
                                .{ tile_width, aspect_preview_size },
                                @splat(0.5),
                                cur,
                            );
                            imgui.window.getDrawList().addRect(
                                @mulAdd(vec.V2, @splat(-0.5), scr_size, center),
                                @mulAdd(vec.V2, @splat(0.5), scr_size, center),
                                color,
                                .{},
                            );
                            cur[1] += aspect_preview_size + imgui.getStyle().itemSpacing.y;
                        }
                        // Size
                        {
                            const pos = .{
                                @mulAdd(f32, -0.5, size_width, h_center),
                                cur[1],
                            };
                            try imgui.window.getDrawList().addFormattedText(
                                "{d} x {d}",
                                .{ mon.min_width, mon.min_height },
                                pos,
                                color,
                            );
                        }
                    },
                    .hor => {
                        // Preview
                        {
                            const avail: vec.V2 = @splat(aspect_preview_size);
                            const scr_size = vec.fit(
                                .{ @floatFromInt(mon.asp_width), @floatFromInt(mon.asp_height) },
                                avail,
                            );
                            const center: vec.V2 = @mulAdd(
                                vec.V2,
                                .{ aspect_preview_size, tile_height },
                                @splat(0.5),
                                cur,
                            );
                            imgui.window.getDrawList().addRect(
                                @mulAdd(vec.V2, @splat(-0.5), scr_size, center),
                                @mulAdd(vec.V2, @splat(0.5), scr_size, center),
                                color,
                                .{},
                            );
                            cur[0] += aspect_preview_size + imgui.getStyle().itemSpacing.x;
                        }
                        imgui.layout.sameLine(.{});
                        // Name
                        {
                            const pos = cur;
                            try imgui.window.getDrawList().addFormattedText(
                                name_format,
                                .{ dirty_indicator, mon.name_buf[0..].ptr },
                                pos,
                                color,
                            );
                            cur[1] += imgui.layout.lineHeightWithSpacing();
                        }
                        // Size
                        {
                            const pos = cur;
                            try imgui.window.getDrawList().addFormattedText(
                                "{d} x {d}",
                                .{ mon.min_width, mon.min_height },
                                pos,
                                color,
                            );
                        }
                    },
                }
            }
        }
        if (layout_dir == .hor) imgui.layout.sameLine(.{});
        if (self.selected) |selidx| {
            const info = &self.items.items[selidx];
            if (imgui.input.text("Name", &info.name_buf, .{})) {
                info.dirty = true;
            }

            if (info.id == null) {
                {
                    imgui.text.raw("Aspect");
                    imgui.layout.indent(.{});
                    defer imgui.layout.unindent(.{});
                    if (imgui.dragValue(u32, "Width##Aspect", &info.asp_width, .{ .min = 1 })) {
                        info.min_width = info.min_height / info.asp_height * info.asp_width;
                    }
                    if (imgui.dragValue(u32, "Height##Aspect", &info.asp_height, .{ .min = 1 })) {
                        info.min_height = info.min_width / info.asp_width * info.asp_height;
                    }
                }

                {
                    imgui.text.raw("Minimum size");
                    imgui.layout.indent(.{});
                    defer imgui.layout.unindent(.{});
                    if (imgui.dragValue(u32, "Width##Size", &info.min_width, .{
                        .speed = @floatFromInt(info.asp_width),
                    })) {
                        info.min_height = info.min_width / info.asp_width * info.asp_height;
                    }
                    if (imgui.dragValue(u32, "Height##Size", &info.min_height, .{
                        .speed = @floatFromInt(info.asp_height),
                    })) {
                        info.min_width = info.min_height / info.asp_height * info.asp_width;
                    }
                }
            }

            if (info.deleted) {
                if (imgui.button("Keep", .{})) {
                    info.deleted = false;
                }
            } else if (imgui.button("Delete", .{})) {
                if (info.id == null) {
                    self.selected = null;
                    _ = self.items.orderedRemove(selidx);
                } else {
                    info.deleted = true;
                }
            }
            if (info.dirty and !info.deleted and info.id != null) {
                imgui.layout.sameLine(.{});
                if (imgui.button("Reset", .{})) {
                    info.set_name(self.originals[selidx].name);
                    info.dirty = false;
                }
            }
        }

        menu: {
            if (!imgui.menu.bar.begin()) break :menu;
            defer imgui.menu.bar.end();

            const has_new = self.items.items.len > self.originals.len;
            const dirty = has_renamed or has_deleted or has_new;

            if (imgui.menu.item("Save", .{ .enabled = dirty })) {
                imgui.popup.open("Save Confirmation", .{});
            }

            if (imgui.popup.beginModal("Save Confirmation", .{
                .flags = .{ .NoResize = true, .AlwaysAutoResize = true },
            })) {
                defer imgui.popup.end();

                imgui.text.raw("This operation will:");
                if (has_new) {
                    imgui.text.raw("Create:");
                    for (self.items.items[self.originals.len..]) |it| {
                        imgui.bullet();
                        try imgui.text.formatted("{s}: {d} x {d}", .{
                            it.name(),
                            it.min_width,
                            it.min_height,
                        });
                    }
                }
                if (has_renamed) {
                    imgui.text.raw("Rename:");
                    for (self.items.items[0..self.originals.len], self.originals) |it, orig| {
                        if (!it.dirty) continue;
                        imgui.bullet();
                        try imgui.text.formatted("{s} -> {s}", .{
                            orig.name,
                            it.name(),
                        });
                    }
                }
                if (has_deleted) {
                    imgui.text.raw("Delete:");
                    for (self.items.items[0..self.originals.len]) |it| {
                        if (!it.deleted) continue;
                        imgui.bullet();
                        try imgui.text.formatted("{s} and its {d} wallpapers", .{
                            it.name(),
                            0,
                        });
                    }
                }

                imgui.layout.spacing();

                if (imgui.button("OK", .{ .size = .{ 120, 0 } })) {
                    var to_delete: std.ArrayListUnmanaged(Db.monitors.ID) =
                        try .initCapacity(allocator, self.originals.len);
                    var renames: std.ArrayListUnmanaged(Db.monitors.RenameDelta) =
                        try .initCapacity(allocator, self.originals.len);
                    var new: std.ArrayListUnmanaged(Db.monitors.NewData) =
                        try .initCapacity(allocator, self.items.items.len - self.originals.len);

                    for (self.items.items) |it| {
                        if (it.id == null) {
                            const new_mon = new.addOneAssumeCapacity();
                            new_mon.name = try allocator.dupeZ(u8, it.name());
                            new_mon.width = it.min_width;
                            new_mon.height = it.min_height;
                        } else if (it.deleted) {
                            const id = to_delete.addOneAssumeCapacity();
                            id.* = it.id.?;
                        } else if (it.dirty) {
                            const rename = renames.addOneAssumeCapacity();
                            rename.id = it.id.?;
                            rename.name = try allocator.dupeZ(u8, it.name());
                        }
                    }
                    const deltas: Db.monitors.Deltas = .{
                        .new = try new.toOwnedSlice(allocator),
                        .delete = try to_delete.toOwnedSlice(allocator),
                        .rename = try renames.toOwnedSlice(allocator),
                    };
                    _ = mbx.work.send(.{ .mons = .{ .update = deltas } });

                    imgui.popup.close();
                }
                imgui.layout.sameLine(.{});
                if (imgui.button("Cancel", .{ .size = .{ 120, 0 } })) {
                    imgui.popup.close();
                }
            }

            if (imgui.menu.item("Reset", .{ .enabled = dirty })) {
                imgui.popup.open("Discard Confirmation", .{});
            }

            if (imgui.popup.beginModal("Discard Confirmation", .{})) {
                defer imgui.popup.end();
                imgui.text.raw("Discard all changes?");

                if (imgui.button("Yes", .{ .size = .{ 120, 0 } })) {
                    try self.reset(allocator, null);
                    imgui.popup.close();
                }
                imgui.layout.sameLine(.{});
                if (imgui.button("No", .{ .size = .{ 120, 0 } })) {
                    imgui.popup.close();
                }
            }
        }
        return open;
    }

    pub const draw = master_detail;
};

pub const WorkMsg = union(enum) {
    /// Request monitors database update
    update: Db.monitors.Deltas,
};

pub const work = struct {
    pub fn handle_msg(worker: *root.Worker, msg: WorkMsg) !void {
        switch (msg) {
            .update => |deltas| {
                defer {
                    for (deltas.rename) |d| worker.allocator.free(d.name);
                    for (deltas.new) |d| worker.allocator.free(d.name);
                    worker.allocator.free(deltas.rename);
                    worker.allocator.free(deltas.new);
                    worker.allocator.free(deltas.delete);
                }
                const mons = try Db.monitors.update(&worker.db, worker.allocator, deltas);
                _ = worker.mbx.gui.send(.{ .replace_monitors = mons });
            },
        }
    }
};
