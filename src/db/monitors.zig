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

/// Update monitors according to the given deltas.
/// Returns a newly allocated slice with all monitors, including those
/// unchanged.
pub fn update(db: *Db, allocator: std.mem.Allocator, deltas: Deltas) ![]Monitor {
    try db.begin();

    {
        var del_stmt = try db.cnx.prepare(
            \\ DELETE FROM monitors
            \\ WHERE ID = :id
        , .{});
        defer del_stmt.finalize();
        for (deltas.delete) |id_to_delete| {
            try del_stmt.bind(.{ .id = id_to_delete });
            _ = try del_stmt.step();
            del_stmt.reset();
        }
    }

    {
        var update_stmt = try db.cnx.prepare(
            \\ UPDATE monitors
            \\ SET name = :name
            \\ WHERE monitors.ID = :id
        , .{});
        defer update_stmt.finalize();
        for (deltas.rename) |delta| {
            try update_stmt.bind(.{
                .id = delta.id,
                .name = delta.name,
            });
            _ = try update_stmt.step();
            update_stmt.reset();
        }
    }

    {
        var insert_stmt = try db.cnx.prepare(
            \\ INSERT INTO monitors
            \\ (name, width, height)
            \\ VALUES
            \\ (:name, :width, :height)
        , .{});
        defer insert_stmt.finalize();
        for (deltas.new) |monitor| {
            try insert_stmt.bind(.{
                .name = monitor.name,
                .width = monitor.width,
                .height = monitor.height,
            });
            insert_stmt.reset();
        }
    }

    try db.commit();
    return get_all(db, allocator);
}

pub const ID = u64;

pub const Monitor = struct {
    id: ID,
    width: u32,
    height: u32,
    name: [:0]const u8,
};

pub const Deltas = struct {
    new: []NewData,
    delete: []ID,
    rename: []RenameDelta,
};

pub const RenameDelta = struct {
    id: ID,
    name: [:0]const u8,
};

/// The data to record into the database.
pub const NewData = struct {
    name: [:0]const u8,
    width: u32,
    height: u32,
};
