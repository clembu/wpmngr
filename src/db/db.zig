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

pub const monitors = @import("monitors.zig");
