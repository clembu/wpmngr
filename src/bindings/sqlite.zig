const std = @import("std");

const Log = std.log.scoped(.sqlite);

pub fn lib_version() [:0]const u8 {
    return std.mem.span(sqlite3_libversion());
}
extern fn sqlite3_libversion() [*:0]const u8;

extern fn sqlite3_free(?*anyopaque) void;

pub const Db = *opaque {
    pub fn open(path: [:0]const u8) !Db {
        var db: ?Db = null;
        const res = sqlite3_open(path.ptr, &db);
        return switch (res) {
            .OK => db.?,
            else => |e| e.to_error(),
        };
    }
    extern fn sqlite3_open([*:0]const u8, ?*?Db) Rc;

    pub fn close(self: Db) !void {
        switch (sqlite3_close(self)) {
            .OK => {},
            else => |e| return e.to_error(),
        }
    }
    extern fn sqlite3_close(Db) Rc;

    pub fn exec(self: Db, sql: [:0]const u8) !void {
        var errmsg: ?[*:0]u8 = null;
        switch (sqlite3_exec(self, sql, null, null, &errmsg)) {
            .OK => {},
            else => |e| {
                if (errmsg) |msg| {
                    Log.err("{s}", .{std.mem.span(msg)});
                    sqlite3_free(errmsg);
                }
                return e.to_error();
            },
        }
    }
    extern fn sqlite3_exec(Db, [*:0]const u8, ?*const fn (*anyopaque, u32, [*][*:0]const u8, [*][*:0]const u8) u32, ?*anyopaque, ?*?[*:0]u8) Rc;

    pub fn prepare(self: Db, sql: [:0]const u8, opts: struct {
        flags: PrepFlags = .{},
    }) !Stmt {
        var stmt: ?Stmt = null;
        // len + 1 because of the sentinel
        switch (sqlite3_prepare_v3(self, sql, @intCast(sql.len + 1), opts.flags, &stmt, null)) {
            .OK => {},
            else => |e| {
                return e.to_error();
            },
        }
        return stmt.?;
    }
    extern fn sqlite3_prepare_v3(Db, [*:0]const u8, u32, PrepFlags, *?Stmt, ?*?*[*:0]const u8) Rc;

    pub const PrepFlags = packed struct(u32) {
        persistent: bool = false,
        normalize: bool = false,
        no_vtab: bool = false,
        _unused_4: bool = false,
        dont_log: bool = false,
        _unused_6_32: u27 = 0,
    };
};

pub const Stmt = *opaque {
    pub fn step(self: Stmt) !?Row {
        switch (sqlite3_step(self)) {
            .ROW, .OK => return @ptrCast(self),
            .DONE => return null,
            else => |e| {
                return e.to_error();
            },
        }
    }
    extern fn sqlite3_step(Stmt) Rc;

    pub fn finalize(self: Stmt) void {
        switch (sqlite3_finalize(self)) {
            .OK => return,
            else => |e| std.debug.panic(
                "SQLite statement finalization errored with code {any}",
                .{e},
            ),
        }
    }
    extern fn sqlite3_finalize(Stmt) Rc;

    pub fn bind(self: Stmt, params: anytype) !void {
        const paramsType = @typeInfo(@TypeOf(params));
        switch (paramsType) {
            .@"struct" => |paramstruct| {
                inline for (paramstruct.fields) |param| {
                    const name = param.name;
                    const sql_name = std.fmt.comptimePrint(":{s}", .{param.name});
                    const idx = sqlite3_bind_parameter_index(self, sql_name);
                    if (idx == 0) {
                        Log.err("Could not find parameter requested: {s}", .{sql_name});
                        return error.ParamNameNotFound;
                    }
                    const rc = switch (param.type) {
                        f32 => sqlite3_bind_double(self, idx, @floatCast(@field(params, name))),
                        f64 => sqlite3_bind_double(self, idx, @field(params, name)),
                        i32 => sqlite3_bind_int(self, idx, @field(params, name)),
                        u32 => sqlite3_bind_int(self, idx, @bitCast(@field(params, name))),
                        i64 => sqlite3_bind_int64(self, idx, @field(params, name)),
                        u64 => sqlite3_bind_int64(self, idx, @bitCast(@field(params, name))),
                        [:0]const u8 => blk: {
                            const slice = @field(params, name);
                            const rc = sqlite3_bind_text(
                                self,
                                idx,
                                slice.ptr,
                                @intCast(slice.len),
                                -1,
                            );
                            break :blk rc;
                        },
                        ?[:0]const u8 => blk: {
                            const slice = @field(params, name);
                            const rc = if (slice) |s|
                                sqlite3_bind_text(self, idx, s.ptr, @intCast(s.len), -1)
                            else
                                sqlite3_bind_null(self, idx);

                            break :blk rc;
                        },
                        else => |t| @compileError(std.fmt.comptimePrint(
                            "Binding is currently not supported for type {any}",
                            .{t},
                        )),
                    };
                    switch (rc) {
                        .OK => {},
                        else => |e| return e.to_error(),
                    }
                }
            },
            else => @compileError("Expected a struct, got something else"),
        }
    }
    extern fn sqlite3_bind_double(Stmt, u32, f64) Rc;
    extern fn sqlite3_bind_int(Stmt, u32, i32) Rc;
    extern fn sqlite3_bind_int64(Stmt, u32, i64) Rc;
    // NOTE: The last parameter of `bind_text` should be a function pointer for
    // the destructor of the string parameter.
    // I only need `SQLITE_TRANSIENT` right now, and I think `SQLITE_STATIC`
    // should be enough otherwise. It'll change when it changes.
    extern fn sqlite3_bind_text(Stmt, u32, ?[*:0]const u8, u32, isize) Rc;
    extern fn sqlite3_bind_null(Stmt, u32) Rc;
    extern fn sqlite3_bind_parameter_index(Stmt, [*:0]const u8) u32;

    pub fn reset(self: Stmt) void {
        switch (sqlite3_reset(self)) {
            .OK => return,
            else => |e| std.debug.panic(
                "Statement reset failed with error code {any}",
                .{e},
            ),
        }
    }
    extern fn sqlite3_reset(Stmt) Rc;
};

// Column accessor view of a Statement
// Same pointer as a Stmt, but only valid after a `step`
pub const Row = *opaque {
    pub fn get_blob(row: Row, idx: u32) ?[]const u8 {
        const ptr = sqlite3_column_blob(row, idx);
        if (ptr) |p| {
            const len = sqlite3_column_bytes(row, idx);
            return (p[0..len]);
        }
        return null;
    }

    pub fn get_f64(row: Row, idx: u32) f64 {
        return sqlite3_column_double(row, idx);
    }

    /// All floats are stored in 64bit. This performs a lossy downcast.
    pub fn get_f32(row: Row, idx: u32) f32 {
        const dbl = row.get_f64(idx);
        return @floatCast(dbl);
    }

    pub fn get_int(row: Row, idx: u32, comptime IntType: type) IntType {
        switch (IntType) {
            u32 => return @bitCast(sqlite3_column_int(row, idx)),
            i32 => return sqlite3_column_int(row, idx),
            u64 => return @bitCast(sqlite3_column_int64(row, idx)),
            i64 => return sqlite3_column_int64(row, idx),
            else => @compileError("Type must be an integer type of size 32 or 64"),
        }
    }

    pub fn get_text(row: Row, idx: u32) ?[:0]const u8 {
        const ptr = sqlite3_column_text(row, idx);
        if (ptr) |p| {
            // `len` does not contain the sentinel
            const len = sqlite3_column_bytes(row, idx);
            return (@ptrCast(p[0..len]));
        }
        return null;
    }

    pub fn get_text16(row: Row, idx: u32) ?[:0]const u16 {
        const ptr = sqlite3_column_text16(row, idx);
        if (ptr) |p| {
            // `len` does not contain the sentinel,
            // and is the number of *bytes*
            const len = sqlite3_column_bytes16(row, idx) / 2;
            return (@ptrCast(p[0..len]));
        }
        return null;
    }

    extern fn sqlite3_column_blob(Row, u32) ?[*]const u8; // Blob
    extern fn sqlite3_column_double(Row, u32) f64;
    extern fn sqlite3_column_int(Row, u32) i32;
    extern fn sqlite3_column_int64(Row, u32) i64;
    extern fn sqlite3_column_text(Row, u32) ?[*:0]const u8;
    extern fn sqlite3_column_text16(Row, u32) ?[*:0]const u16;
    extern fn sqlite3_column_bytes(Row, u32) u32;
    extern fn sqlite3_column_bytes16(Row, u32) u32;
};

const Rc = enum(u32) {
    OK = 0x00,
    ERROR = 0x01,
    INTERNAL = 0x02,
    PERM = 0x03,
    ABORT = 0x04,
    BUSY = 0x05,
    LOCKED = 0x06,
    NOMEM = 0x07,
    READONLY = 0x08,
    INTERRUPT = 0x09,
    IOERR = 0x0A,
    CORRUPT = 0x0B,
    NOTFOUND = 0x0C,
    FULL = 0x0D,
    CANTOPEN = 0x0E,
    PROTOCOL = 0x0F,
    EMPTY = 0x10,
    SCHEMA = 0x11,
    TOOBIG = 0x12,
    CONSTRAINT = 0x13,
    MISMATCH = 0x14,
    MISUSE = 0x15,
    NOLFS = 0x16,
    AUTH = 0x17,
    FORMAT = 0x18,
    RANGE = 0x19,
    NOTADB = 0x1A,
    NOTICE = 0x1B,
    WARNING = 0x1C,
    ROW = 0x64, // 100
    DONE = 0x65, // 101

    pub fn to_error(rc: Rc) Error {
        return switch (rc) {
            .OK => unreachable, // Not an error
            .ROW => unreachable, // Not an error
            .DONE => unreachable, // Not an error
            .ERROR => Error.SqliteError,
            .INTERNAL => Error.SqliteInternal,
            .PERM => Error.SqlitePerm,
            .ABORT => Error.SqliteAbort,
            .BUSY => Error.SqliteBusy,
            .LOCKED => Error.SqliteLocked,
            .NOMEM => Error.SqliteNomem,
            .READONLY => Error.SqliteReadonly,
            .INTERRUPT => Error.SqliteInterrupt,
            .IOERR => Error.SqliteIoerr,
            .CORRUPT => Error.SqliteCorrupt,
            .NOTFOUND => Error.SqliteNotfound,
            .FULL => Error.SqliteFull,
            .CANTOPEN => Error.SqliteCantopen,
            .PROTOCOL => Error.SqliteProtocol,
            .EMPTY => Error.SqliteEmpty,
            .SCHEMA => Error.SqliteSchema,
            .TOOBIG => Error.SqliteToobig,
            .CONSTRAINT => Error.SqliteConstraint,
            .MISMATCH => Error.SqliteMismatch,
            .MISUSE => Error.SqliteMisuse,
            .NOLFS => Error.SqliteNolfs,
            .AUTH => Error.SqliteAuth,
            .FORMAT => Error.SqliteFormat,
            .RANGE => Error.SqliteRange,
            .NOTADB => Error.SqliteNotadb,
            .NOTICE => Error.SqliteNotice,
            .WARNING => Error.SqliteWarning,
        };
    }
};

pub const Error = error{
    SqliteError,
    SqliteInternal,
    SqlitePerm,
    SqliteAbort,
    SqliteBusy,
    SqliteLocked,
    SqliteNomem,
    SqliteReadonly,
    SqliteInterrupt,
    SqliteIoerr,
    SqliteCorrupt,
    SqliteNotfound,
    SqliteFull,
    SqliteCantopen,
    SqliteProtocol,
    SqliteEmpty,
    SqliteSchema,
    SqliteToobig,
    SqliteConstraint,
    SqliteMismatch,
    SqliteMisuse,
    SqliteNolfs,
    SqliteAuth,
    SqliteFormat,
    SqliteRange,
    SqliteNotadb,
    SqliteNotice,
    SqliteWarning,
};
