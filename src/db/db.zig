const sqlite = @import("sqlite");
const std = @import("std");

cnx: sqlite.Db,

pub fn init(dbpath: [:0]const u8) !@This() {
    var db: @This() = .{ .cnx = try .open(dbpath) };
    errdefer db.deinit();
    try db.cnx.exec(@embedFile("db.sql"));
    return db;
}

pub fn deinit(self: *@This()) void {
    var busy = true;
    while (busy) {
        busy = false;
        self.cnx.close() catch {
            busy = true;
        };
    }
}

pub fn begin(self: *@This()) !void {
    try self.cnx.exec("BEGIN");
}

pub fn commit(self: *@This()) !void {
    try self.cnx.exec("COMMIT");
}

pub fn get_monitors(self: *@This(), allocator: std.mem.Allocator) ![]Monitor {
    var stmt = try self.cnx.prepare("SELECT * FROM monitors", .{});
    defer stmt.finalize();
    var al = try std.ArrayListUnmanaged(Monitor).initCapacity(allocator, 4);
    errdefer al.deinit(allocator);
    while (try stmt.step()) |row| {
        var mon: *Monitor = try al.addOne(allocator);
        mon.id = row.get_int(0, u64);
        mon.name = try allocator.dupeZ(u8, row.get_text(1).?);
        mon.width = row.get_int(2, u32);
        mon.height = row.get_int(3, u32);
    }
    const result = try al.toOwnedSlice(allocator);
    return result;
}

pub fn delete_monitor(self: *@This(), id: u64) !void {
    try self.begin();
    var del_stmt = try self.cnx.prepare("DELETE FROM monitors WHERE ID = :id", .{});
    defer del_stmt.finalize();
    try del_stmt.bind(.{ .id = id });
    _ = try del_stmt.step();
    del_stmt.reset();
    try self.commit();
}

pub fn rename_monitor(self: *@This(), id: u64, name: [:0]const u8) !void {
    try self.begin();
    var update_stmt = try self.cnx.prepare(
        \\ UPDATE monitors
        \\ SET name = :name
        \\ WHERE monitors.ID = :id
    , .{});
    defer update_stmt.finalize();
    try update_stmt.bind(.{
        .id = id,
        .name = name,
    });
    _ = try update_stmt.step();
    update_stmt.reset();
    try self.commit();
}

pub fn add_monitor(self: *@This(), monitor: Monitor.NewData) !Monitor {
    try self.begin();
    var insert_stmt = try self.cnx.prepare(
        \\ INSERT INTO monitors
        \\ (name, width, height)
        \\ VALUES
        \\ (:name, :width, :height)
        \\ RETURNING ID;
    , .{});
    defer insert_stmt.finalize();
    try insert_stmt.bind(.{
        .name = monitor.name,
        .width = monitor.width,
        .height = monitor.height,
    });
    const row = try insert_stmt.step();
    const id = row.?.get_int(0, u64);
    insert_stmt.reset();

    try self.commit();
    return .{
        .id = id,
        .name = monitor.name,
        .width = monitor.width,
        .height = monitor.height,
    };
}

pub const Monitor = struct {
    id: u64,
    name: [:0]const u8,
    width: u32,
    height: u32,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }

    pub const NewData = struct {
        name: [:0]const u8,
        width: u32,
        height: u32,
    };
};
