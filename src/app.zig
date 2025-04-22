const std = @import("std");
const imgui = @import("bindings/imgui.zig");
const vec = @import("vec.zig");
const spsc = @import("spsc.zig");
const Cropper = @import("cropper.zig");
const Image = @import("image.zig");
const Db = @import("db/db.zig");
const MonitorsWindow = @import("views/monitors.zig");

allocator: std.mem.Allocator,
cropper: ?Cropper,
db_ready: bool,
op_err: ?anyerror,
test_image_filename: [255:0]u8,
monitors: std.ArrayListUnmanaged(Db.Monitor),
displays: []DisplaySize,
monitors_window: MonitorsWindow,
req: *WorkMsgQueue,

pub fn init(allocator: std.mem.Allocator, req: *WorkMsgQueue, displays: []DisplaySize) !@This() {
    return .{
        .allocator = allocator,
        .cropper = null,
        .db_ready = false,
        .op_err = null,
        .test_image_filename = @splat(0),
        .monitors = try .initCapacity(allocator, 6),
        .displays = displays,
        .monitors_window = .init,
        .req = req,
    };
}

pub fn deinit(self: *@This()) void {
    self.allocator.free(self.displays);
    for (self.monitors.items) |*mon| mon.deinit(self.allocator);
    self.monitors.deinit(self.allocator);
}

pub fn set_image(self: *@This(), image: Image) void {
    self.cropper = .init(image, .{ 9, 16 }, .{ 1080, 1920 });
}

pub fn set_monitors(self: *@This(), monitors: []Db.Monitor) !void {
    for (self.monitors.items) |*mon| mon.deinit(self.allocator);
    try self.monitors.replaceRange(self.allocator, 0, self.monitors.items.len, monitors);
}

pub fn update(self: *@This()) !void {
    if (self.cropper == null) {
        _ = imgui.input.text("Test image filename", &self.test_image_filename, .{});
        if (imgui.button("Load Test Image", .{})) {
            _ = self.req.send(.{ .load_image_file = std.mem.span(self.test_image_filename[0..].ptr) });
        }
    }
    // if (self.monitors == null) {
    //     if (imgui.button("Get Monitors", .{})) {
    //         _ = self.req.send(.get_monitors);
    //     }
    // }

    _ = imgui.dockSpace.overViewport(.{});
    if (self.cropper) |*cr| try cr.update();
    {
        const show_win = imgui.window.begin("About SQLite", .{});
        defer imgui.window.end();
        if (show_win) {
            if (self.db_ready) {
                const version = @import("sqlite").lib_version();
                try imgui.text.formatted("SQLite Version: {s}", .{version});
            } else {
                imgui.loadingBar(.{ .overlay = "Getting ready" });
            }
        }
    }

    {
        try self.monitors_window.draw(self.allocator, self.monitors.items);
    }

    if (self.op_err) |err| {
        const show_win = imgui.window.begin("Error", .{});
        defer imgui.window.end();
        if (show_win) {
            try imgui.text.formatted("{any}", .{err});
        }
    }
}

pub fn handle_msg(self: *@This(), msg: AppMsg) !void {
    switch (msg) {
        .db_ready => self.db_ready = true,
        .new_monitor => |mon| {
            try self.monitors.append(self.allocator, mon);
        },
        .delete_monitor => |id| {
            if (self.monitors.items.len == 0) return;
            const idx: ?usize = blk: for (self.monitors.items, 0..) |m, idx| {
                if (m.id == id) {
                    std.debug.print("Found index {d} for id {d}\n", .{ idx, id });
                    break :blk idx;
                }
            } else null;
            if (idx) |i| {
                var mon = self.monitors.orderedRemove(i);
                std.debug.print("Deleting index {d}\n", .{i});
                mon.deinit(self.allocator);
            }
        },
        .monitors => |mons| {
            try self.set_monitors(mons);
            self.allocator.free(mons);
        },
    }
}

pub fn set_error(self: *@This(), err: ?anyerror) void {
    self.op_err = err;
}

pub const WorkMsg = union(enum) {
    load_image_file: [:0]const u8,
    monitors: MonitorsWindow.WorkMsg,

    quit,
};
pub const WorkMsgQueue = spsc.SPSC(WorkMsg, 64);

pub const AppMsg = union(enum) {
    db_ready,
    new_monitor: Db.Monitor,
    delete_monitor: u64,
    monitors: []Db.Monitor,
};

pub const DisplaySize = struct {
    width: u32,
    height: u32,
};
