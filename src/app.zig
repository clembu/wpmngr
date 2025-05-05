const std = @import("std");
const root = @import("root");
const Db = @import("db/db.zig");
const imgui = @import("bindings/imgui.zig");

pub const monitors = @import("monitors.zig");

pub const GuiMsg = union(enum) {
    ready: Gui.CoreData,
    err: anyerror,
    replace_monitors: []Db.monitors.Monitor,
};

pub const WorkMsg = union(enum) {
    quit,
    mons: monitors.WorkMsg,
};

// TODO: re-integrate cropper test view
pub const Gui = struct {
    allocator: std.mem.Allocator,
    mbx: *root.Mailbox,
    core: ?CoreData = null,
    err: ?anyerror = null,
    show_err: bool = false,
    rt: root.GuiRT,
    displays: []monitors.Display,
    monswin: ?monitors.ListWindow = null,

    pub const CoreData = struct {
        monitors: []Db.monitors.Monitor,

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            self.free_monitors(allocator);
        }

        pub fn free_monitors(self: *@This(), allocator: std.mem.Allocator) void {
            for (self.monitors) |mon| allocator.free(mon.name);
            allocator.free(self.monitors);
        }
    };

    pub const CreationParameters = struct {
        allocator: std.mem.Allocator,
        mbx: *root.Mailbox,
    };

    pub fn init(rt: root.GuiRT, params: CreationParameters) !@This() {
        const displays = try rt.getDisplays(params.allocator);
        return .{
            .allocator = params.allocator,
            .mbx = params.mbx,
            .rt = rt,
            .displays = displays,
        };
    }

    pub fn deinit(self: *@This()) void {
        if (self.monswin) |*win| win.deinit(self.allocator);
        if (self.core) |*data| {
            data.deinit(self.allocator);
        }
        self.allocator.free(self.displays);
        self.rt.deinit();
    }

    pub fn handle_msg(self: *@This(), msg: GuiMsg) !void {
        switch (msg) {
            .ready => |init_data| {
                self.core = init_data;
                // NOTE: TEMP:
                self.monswin = try .init(self.allocator, init_data.monitors);
            },
            .err => |e| {
                self.err = e;
                self.show_err = true;
            },
            .replace_monitors => |mons| {
                if (self.core) |*core| {
                    core.free_monitors(self.allocator);
                    core.monitors = mons;
                    if (self.monswin) |*win| try win.reset(self.allocator, core.monitors);
                }
            },
        }
    }

    pub fn update(self: *@This()) !void {
        _ = imgui.dockSpace.overViewport(.{});

        if (self.monswin) |*win| try win.draw(self.allocator, self.displays, self.mbx);

        if (self.err) |e| {
            if (imgui.popup.beginModal("Error", .{ .open = &self.show_err })) {
                defer imgui.popup.end();

                imgui.text.raw(@errorName(e));
                if (imgui.button("OK", .{ .size = .{ 240, 0 } })) {
                    imgui.popup.close();
                }
            }
        }
    }
};

pub const Worker = struct {
    allocator: std.mem.Allocator,
    rt: root.WorkRT,
    db: Db,
    mbx: *root.Mailbox,

    pub fn init(allocator: std.mem.Allocator, mbx: *root.Mailbox, dbpath: [:0]const u8) !@This() {
        const rt: root.WorkRT = try .init();
        var db: Db = try .init(dbpath);
        allocator.free(dbpath);
        errdefer db.deinit();
        const mons = try Db.monitors.get_all(&db, allocator);
        _ = mbx.gui.send(.{ .ready = .{ .monitors = mons } });
        return .{
            .db = db,
            .rt = rt,
            .mbx = mbx,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.rt.deinit();
        self.db.deinit();
    }

    pub fn run(self: *@This()) !void {
        var listen = true;
        while (listen) {
            if (self.mbx.work.receive()) |req| {
                switch (req) {
                    .quit => {
                        listen = false;
                    },
                    .mons => |mon_msg| {
                        if (monitors.work.handle_msg(self, mon_msg)) {} else |err| {
                            _ = self.mbx.gui.send(.{ .err = err });
                        }
                    },
                }
            }
            // Two cases:
            // 1. There are no messages to listen: we yield rather than directly
            // check again.
            // 2. We just processed a message, no need to be greedy, we can yield
            std.Thread.yield() catch {};
        }
    }
};
