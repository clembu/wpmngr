const sqlite = @import("sqlite");
const std = @import("std");
const Db = @import("db.zig");

/// Get all monitors in a single array.
/// Names are allocated as part of each monitor's initialization
pub fn get_all(db: *Db, allocator: std.mem.Allocator) ![]Monitor {
    var stmt = try db.cnx.prepare("SELECT * FROM monitors", .{});
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

pub fn delete(db: *Db, id: ID) !void {
    try db.begin();
    var del_stmt = try db.cnx.prepare("DELETE FROM monitors WHERE ID = :id", .{});
    defer del_stmt.finalize();
    try del_stmt.bind(.{ .id = id });
    _ = try del_stmt.step();
    del_stmt.reset();
    try db.commit();
}

pub fn rename(db: *Db, id: u64, name: [:0]const u8) !void {
    try db.begin();
    var update_stmt = try db.cnx.prepare(
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
    try db.commit();
}

/// Ownership of the name slice is transferred to the returned Monitor,
/// unless the call errors.
pub fn add_one(self: *@This(), monitor: NewData) !Monitor {
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

pub const ID = u64;

pub const Monitor = struct {
    id: ID,
    width: u32,
    height: u32,
    name: [:0]const u8,
};

/// The data to record into the database.
pub const NewData = struct {
    name: [:0]const u8,
    width: u32,
    height: u32,
};
