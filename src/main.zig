const std = @import("std");
const builtin = @import("builtin");
const spsc = @import("spsc.zig");
const imgui = @import("bindings/imgui.zig");
const Db = @import("db/db.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    _ = args.skip(); // Skip the command itself.
    const dbpath = try alloc.dupeZ(u8, try (args.next() orelse error.MissingDbPathArg));
    errdefer alloc.free(dbpath);
    args.deinit();

    var mbx: Mailbox = .{};

    const worker = try std.Thread.spawn(.{}, run_worker, .{ alloc, &mbx, dbpath });
    defer worker.join();

    var runner = try AppRunner.init(.{ .mbx = &mbx, .allocator = alloc });
    defer runner.deinit();

    imgui.config.SetFlags(.{ .DockingEnable = true });

    try runner.run();
}

pub const Mailbox = struct {
    work: spsc.SPSC(WorkMsg, 64) = .{},
    gui: spsc.SPSC(GuiMsg, 8) = .{},
};

pub const GuiMsg = union(enum) {
    ready: Gui.CoreData,
    // TODO: gui message type (response)
};

pub const WorkMsg = union(enum) {
    quit,
    // TODO: worker message type (request)
};

fn run_worker(allocator: std.mem.Allocator, com: *Mailbox, dbpath: [:0]const u8) !void {
    const Log = std.log.scoped(.worker_thread);
    Log.info("Worker is starting", .{});

    var worker: Worker = try .init(allocator, com, dbpath);
    defer worker.deinit();

    try worker.run();

    Log.info("Worker is stopping", .{});
}

pub const Worker = struct {
    allocator: std.mem.Allocator,
    rt: WorkRT,
    db: Db,
    mbx: *Mailbox,

    pub fn init(allocator: std.mem.Allocator, mbx: *Mailbox, dbpath: [:0]const u8) !@This() {
        var db: Db = try .init(dbpath);
        allocator.free(dbpath);
        errdefer db.deinit();
        const monitors = try Db.monitors.get_all(&db, allocator);
        _ = mbx.gui.send(.{ .ready = .{ .monitors = monitors } });
        return .{
            .db = db,
            .rt = try .init(),
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

pub const WorkRT = switch (builtin.os.tag) {
    .windows => @import("workrt/win32.zig"),
    else => @compileError("Only windows is supported for now"),
};

pub const GuiRT = switch (builtin.os.tag) {
    .windows => @import("guirt/win32.zig"),
    else => @compileError("Only windows is supported for now"),
};

pub const AppRunner = switch (builtin.os.tag) {
    .windows => @import("guirunner/win32.zig"),
    else => @compileError("Only windows is supported for now"),
};

// TODO: move out to file after refactor
pub const Gui = struct {
    allocator: std.mem.Allocator,
    mbx: *Mailbox,
    core: ?CoreData = null,
    rt: GuiRT,

    pub const CoreData = struct {
        monitors: []Db.monitors.Monitor,
    };

    pub const CreationParameters = struct {
        allocator: std.mem.Allocator,
        mbx: *Mailbox,
    };

    pub fn init(rt: GuiRT, params: CreationParameters) @This() {
        return .{
            .allocator = params.allocator,
            .mbx = params.mbx,
            .rt = rt,
        };
    }

    pub fn deinit(self: *@This()) void {
        if (self.core) |data| {
            for (data.monitors) |mon| self.allocator.free(mon.name);
            self.allocator.free(data.monitors);
        }
        self.rt.deinit();
    }

    pub fn handle_msg(self: *@This(), msg: GuiMsg) !void {
        switch (msg) {
            .ready => |init_data| {
                self.core = init_data;
            },
        }
    }

    pub fn update(self: *@This()) !void {
        // TODO:
        _ = self;
    }
};
