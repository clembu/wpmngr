const std = @import("std");
const root = @import("root");
const Db = @import("db/db.zig");
const imgui = @import("bindings/imgui.zig");

pub const monitors = @import("monitors.zig");
pub const Cropper = @import("cropper.zig");

pub const GuiMsg = union(enum) {
    ready: Gui.CoreData,
    err: anyerror,
    replace_monitors: []Db.monitors.Monitor,
    load_test_texture: root.ImageBuffer, // TEMP:
};

pub const WorkMsg = union(enum) {
    quit,
    mons: monitors.WorkMsg,
    load_test_image, // TEMP:
};

pub const Gui = struct {
    allocator: std.mem.Allocator,
    mbx: *root.Mailbox,
    core: ?CoreData = null,
    err: ?anyerror = null,
    show_err: bool = false,
    rt: root.GuiRT,
    displays: []monitors.Display,
    monswin: ?monitors.ListWindow = null,
    cropper: ?Cropper = null,

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
            // TEMP:
            .load_test_texture => |img| {
                defer self.allocator.free(img.buffer);
                if (self.cropper) |_| {} else {
                    const tx = try self.rt.upload_texture(img);
                    self.cropper = .init(tx, .{ 16.0, 9.0 }, .{ 1920.0, 1080.0 });
                }
            },
        }
    }

    pub fn update(self: *@This()) !void {
        _ = imgui.dockSpace.overViewport(.{});

        menu: {
            if (!imgui.menu.main.begin()) break :menu;
            defer imgui.menu.main.end();

            if (imgui.menu.begin("Views", .{})) {
                defer imgui.menu.end();
                if (self.core) |core| {
                    if (imgui.menu.item("Monitors", .{
                        .selected = self.monswin != null,
                    })) {
                        if (self.monswin) |*win| {
                            win.deinit(self.allocator);
                            self.monswin = null;
                        } else {
                            self.monswin = try .init(self.allocator, core.monitors);
                        }
                    }

                    // TEMP:
                    if (imgui.menu.item("Cropper Test", .{
                        .selected = self.cropper != null,
                    })) {
                        if (self.cropper) |*win| {
                            win.deinit(&self.rt);
                            self.cropper = null;
                        } else {
                            _ = self.mbx.work.send(.load_test_image);
                        }
                    }
                }
            }
        }

        if (self.monswin) |*win| {
            if (!try win.draw(self.allocator, self.displays, self.mbx)) {
                win.deinit(self.allocator);
                self.monswin = null;
            }
        }

        // TEMP:
        if (self.cropper) |*win| try win.update(&self.rt);

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
                    .load_test_image => {
                        if (self.rt.load_image("test_image.jpg", self.allocator)) |img| {
                            _ = self.mbx.gui.send(.{ .load_test_texture = img });
                        } else |err| {
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
