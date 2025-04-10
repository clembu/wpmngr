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

pub fn update_monitors(self: *@This(), deltas: []Monitor.Delta) !void {
    try self.begin();
    var del_stmt = try self.cnx.prepare("DELETE FROM monitors WHERE ID = :id", .{});
    defer del_stmt.finalize();
    var update_stmt = try self.cnx.prepare(
        \\ UPDATE monitors
        \\ SET name = :name
        \\   , width = :width
        \\   , height = :height
        \\ WHERE monitors.ID = :id
    , .{});
    defer update_stmt.finalize();
    var insert_stmt = try self.cnx.prepare(
        \\ INSERT INTO monitors
        \\ ( name, width, height)
        \\ VALUES
        \\ (:name, :width, :height)
    , .{});
    defer insert_stmt.finalize();
    for (deltas) |delta| {
        if (delta.id == null) {
            std.log.debug("Stepping insert statement", .{});
            try insert_stmt.bind(.{
                .name = std.mem.span(delta.name_buf[0..].ptr),
                .width = delta.width,
                .height = delta.height,
            });
            _ = try insert_stmt.step();
            insert_stmt.reset();
        } else if (delta.to_delete) {
            std.log.debug("Stepping delete statement (id = {?d})", .{delta.id});
            try del_stmt.bind(.{ .id = delta.id.? });
            _ = try del_stmt.step();
            del_stmt.reset();
        } else {
            std.log.debug("Stepping update statement (id = {?d})", .{delta.id});
            try update_stmt.bind(.{
                .id = delta.id.?,
                .name = std.mem.span(delta.name_buf[0..].ptr),
                .width = delta.width,
                .height = delta.height,
            });
            _ = try update_stmt.step();
            update_stmt.reset();
        }
    }
    try self.commit();
}

pub const Monitor = struct {
    id: u64,
    name: [:0]u8,
    width: u32,
    height: u32,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }

    pub const Delta = struct {
        id: ?u64,
        name_buf: [255:0]u8,
        width: u32,
        height: u32,
        to_delete: bool,
    };
};
