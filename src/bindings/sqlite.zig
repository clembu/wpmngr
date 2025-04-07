const std = @import("std");

pub fn lib_version() [:0]const u8 {
    return std.mem.span(sqlite3_libversion());
}
extern fn sqlite3_libversion() [*:0]const u8;

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
