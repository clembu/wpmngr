const std = @import("std");
const imgui = @import("bindings/imgui.zig");
const vec = @import("vec.zig");
const spsc = @import("spsc.zig");
const Cropper = @import("cropper.zig");
const Image = @import("image.zig");
const Db = @import("db/db.zig");

allocator: std.mem.Allocator,
cropper: ?Cropper,
db_ready: bool,
op_err: ?anyerror,
test_image_filename: [255:0]u8,
monitors: ?[]Db.Monitor,
monitors_editor: ?MonitorsEditor,

pub fn init(allocator: std.mem.Allocator) @This() {
    return .{
        .allocator = allocator,
        .cropper = null,
        .db_ready = false,
        .op_err = null,
        .test_image_filename = @splat(0),
        .monitors = null,
        .monitors_editor = null,
    };
}

pub fn deinit(self: *@This()) void {
    if (self.monitors) |mons| {
        for (mons) |*mon| mon.deinit(self.allocator);
        self.allocator.free(mons);
    }
    if (self.monitors_editor) |*ed| ed.deinit(self.allocator);
}

pub fn set_image(self: *@This(), image: Image) void {
    self.cropper = .init(image, .{ 9, 16 }, .{ 1080, 1920 });
}

pub fn set_monitors(self: *@This(), monitors: []Db.Monitor) void {
    if (self.monitors) |mons| {
        for (mons) |*mon| mon.deinit(self.allocator);
        self.allocator.free(mons);
    }
    if (self.monitors_editor) |*ed| {
        ed.deinit(self.allocator);
        self.monitors_editor = null;
    }
    self.monitors = monitors;
}

pub fn update(self: *@This(), req: *WorkMsgQueue) !void {
    if (self.cropper == null) {
        _ = imgui.input.text("Test image filename", &self.test_image_filename, .{});
        if (imgui.button("Load Test Image", .{})) {
            _ = req.send(.{ .load_image_file = std.mem.span(self.test_image_filename[0..].ptr) });
        }
    }

    _ = imgui.dockSpace.overViewport(.{});
    if (self.cropper) |*cr| try cr.update();
    {
        const show_win = imgui.window.begin("About SQLite", .{});
        defer imgui.window.end();
        if (show_win) {
            if (self.db_ready) {
                const version = @import("sqlite").lib_version();
                try imgui.text("SQLite Version: {s}", .{version});
            } else {
                imgui.loadingBar(.{ .overlay = "Getting ready" });
            }
        }
    }

    {
        const show_win = imgui.window.begin("Monitors", .{});
        defer imgui.window.end();
        if (show_win) {
            if (imgui.button("Refresh", .{})) {
                _ = req.send(.get_monitors);
            }
            if (self.monitors_editor) |*editor| {
                imgui.layout.sameLine(.{});
                if (imgui.button("Discard", .{})) {
                    editor.deinit(self.allocator);
                    self.monitors_editor = null;
                }
                imgui.layout.sameLine(.{});
                if (imgui.button("Save", .{})) {
                    const deltas = try editor.get_deltas(self.allocator);
                    _ = req.send(.{ .set_monitors = deltas });
                    _ = req.send(.get_monitors);
                }
                imgui.separator(.{});

                for (editor.monitors.items, 0..) |*it, idx| {
                    imgui.ids.pushUSize(idx);
                    defer imgui.ids.pop();
                    if (it.id) |id| {
                        try imgui.text("ID: {d}", .{id});
                    }
                    _ = imgui.input.text("Name", &it.name_buf, .{});
                    try imgui.text("Aspect:", .{});
                    {
                        imgui.layout.indent(.{});
                        defer imgui.layout.unindent(.{});
                        if (imgui.dragInt("Width##Aspect", &it.asp_width, .{})) {
                            it.min_width = it.asp_width * (it.min_height / it.asp_height);
                        }
                        if (imgui.dragInt("Height##Aspect", &it.asp_height, .{})) {
                            it.min_height = it.asp_height * (it.min_width / it.asp_width);
                        }
                    }
                    try imgui.text("Minimum wallpaper size:", .{});
                    {
                        imgui.layout.indent(.{});
                        defer imgui.layout.unindent(.{});
                        if (imgui.dragInt("Width##MinSize", &it.min_width, .{})) {
                            it.min_height = it.asp_height * (it.min_width / it.asp_width);
                        }
                        if (imgui.dragInt("Height##MinSize", &it.min_height, .{})) {
                            it.min_width = it.asp_width * (it.min_height / it.asp_height);
                        }
                    }
                    _ = imgui.checkbox("Mark for deletion", &it.to_delete);
                }
                imgui.separator(.{});
                if (imgui.button("Add", .{})) {
                    try editor.addOne(self.allocator);
                }
            } else if (self.monitors) |mons| {
                imgui.layout.sameLine(.{});
                if (imgui.button("Edit", .{})) {
                    self.monitors_editor = try .init(self.allocator, mons);
                }
                imgui.separator(.{});
                for (mons) |mon| {
                    try imgui.text("{s}", .{mon.name});
                    imgui.layout.indent(.{});
                    try imgui.text("Id: {d}", .{mon.id});
                    try imgui.text("Width: {d}", .{mon.width});
                    try imgui.text("Height: {d}", .{mon.height});
                    imgui.layout.unindent(.{});
                }
            }
        }
    }

    if (self.op_err) |err| {
        const show_win = imgui.window.begin("Error", .{});
        defer imgui.window.end();
        if (show_win) {
            try imgui.text("{any}", .{err});
        }
    }
}

pub fn handle_msg(self: *@This(), msg: AppMsg) void {
    switch (msg) {
        .db_ready => self.db_ready = true,
        .monitors => |mons| {
            self.set_monitors(mons);
        },
    }
}

pub fn set_error(self: *@This(), err: ?anyerror) void {
    self.op_err = err;
}

pub const WorkMsg = union(enum) {
    load_image_file: [:0]const u8,
    get_monitors,
    set_monitors: []Db.Monitor.Delta,
    quit,
};
pub const WorkMsgQueue = spsc.SPSC(WorkMsg, 64);

pub const AppMsg = union(enum) {
    db_ready,
    monitors: []Db.Monitor,
};

const MonitorsEditor = struct {
    selected: ?usize,
    monitors: std.ArrayListUnmanaged(MonitorData),
    const MonitorData = struct {
        id: ?u64,
        name_buf: [255:0]u8,
        asp_width: u32,
        asp_height: u32,
        min_width: u32,
        min_height: u32,
        to_delete: bool,
        const init: @This() = .{
            .id = null,
            .name_buf = @splat(0),
            .asp_width = 16,
            .asp_height = 9,
            .min_width = 1080,
            .min_height = 1920,
            .to_delete = false,
        };
    };

    pub fn init(allocator: std.mem.Allocator, monitors: []Db.Monitor) !@This() {
        var self: @This() = .{
            .selected = null,
            .monitors = try .initCapacity(allocator, monitors.len),
        };
        for (monitors) |mon| {
            var mondata = self.monitors.addOneAssumeCapacity();
            mondata.* = .init;
            mondata.id = mon.id;
            std.mem.copyForwards(u8, &mondata.name_buf, mon.name);
            mondata.min_width = mon.width;
            mondata.min_height = mon.height;
            const gcd = std.math.gcd(mon.width, mon.height);
            mondata.asp_width = mon.width / gcd;
            mondata.asp_height = mon.height / gcd;
        }
        return self;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.monitors.deinit(allocator);
    }

    pub fn get_deltas(self: *@This(), allocator: std.mem.Allocator) ![]Db.Monitor.Delta {
        var deltas = try allocator.alloc(Db.Monitor.Delta, self.monitors.items.len);
        for (self.monitors.items, 0..) |*it, idx| {
            deltas[idx] = .{
                .id = it.id,
                .width = it.min_width,
                .height = it.min_height,
                .name_buf = it.name_buf,
                .to_delete = it.to_delete,
            };
        }
        return deltas;
    }

    fn addOne(self: *@This(), allocator: std.mem.Allocator) !void {
        const mondata = try self.monitors.addOne(allocator);
        mondata.* = .init;
        self.selected = self.monitors.items.len - 1;
    }
};
