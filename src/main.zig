const std = @import("std");
const builtin = @import("builtin");
const spsc = @import("spsc.zig");
const imgui = @import("bindings/imgui.zig");
const Db = @import("db/db.zig");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    try rt.init();
    defer rt.deinit();

    var args = try std.process.argsWithAllocator(alloc);
    _ = args.skip(); // Skip the command itself.
    const dbpath = try alloc.dupeZ(u8, try (args.next() orelse error.MissingDbPathArg));
    errdefer alloc.free(dbpath);
    args.deinit();

    var mbx: Mailbox = .{};

    const worker = try std.Thread.spawn(.{}, run_worker, .{ alloc, &mbx, dbpath });
    defer worker.join();

    var runner = try GuiRunner.init(.{ .mbx = &mbx, .allocator = alloc });
    defer runner.deinit();

    imgui.config.SetFlags(.{ .DockingEnable = true });

    try runner.run();
}

fn run_worker(allocator: std.mem.Allocator, com: *Mailbox, dbpath: [:0]const u8) !void {
    const Log = std.log.scoped(.worker_thread);
    Log.info("Worker is starting", .{});

    var worker: Worker = try .init(allocator, com, dbpath);
    defer worker.deinit();

    try worker.run();

    Log.info("Worker is stopping", .{});
}

pub const app = @import("app.zig");
pub const vec = @import("vec.zig");

const rt = switch (builtin.os.tag) {
    .windows => struct {
        const w32 = @import("bindings/win32.zig");
        pub fn init() !void {
            try w32.com.init(.{});
        }

        pub fn deinit() void {
            w32.com.deinit();
        }
    },
    else => @compileError("Only windows is supported for now"),
};

pub const Mailbox = struct {
    work: spsc.SPSC(app.WorkMsg, 64) = .{},
    gui: spsc.SPSC(app.GuiMsg, 8) = .{},
};

pub const Worker = app.Worker;

pub const WorkRT = switch (builtin.os.tag) {
    .windows => @import("workrt/win32.zig"),
    else => @compileError("Only windows is supported for now"),
};

pub const GuiRT = switch (builtin.os.tag) {
    .windows => @import("guirt/win32.zig"),
    else => @compileError("Only windows is supported for now"),
};

pub const GuiRunner = switch (builtin.os.tag) {
    .windows => @import("guirunner/win32.zig"),
    else => @compileError("Only windows is supported for now"),
};

pub const Gui = app.Gui;

pub const ImageBuffer = struct { width: u32, height: u32, buffer: []const u8 };

