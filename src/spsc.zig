// Circular FIFO based on Charles Frasch
// https://www.youtube.com/watch?v=K3P_Lmq6pw0

const std = @import("std");
const cache_line = std.atomic.cache_line;
const AtomicUSize = std.atomic.Value(usize);

pub fn SPSC(comptime T: type, capacity: comptime_int) type {
    if (capacity == 0) {
        @compileError("Capacity must not be zero.");
    }
    if (!std.math.isPowerOfTwo(capacity)) {
        @compileError("Capacity must be a power of 2.");
    }
    const cap_mask = capacity - 1;
    return struct {
        ring: [capacity]T = undefined,

        write_cursor: AtomicUSize align(cache_line) = AtomicUSize.init(0),
        /// Exclusively used by the reader thread,
        write_cursor_cached: usize align(cache_line) = 0,

        read_cursor: AtomicUSize align(cache_line) = AtomicUSize.init(0),
        /// Exclusively used by the writer thread,
        read_cursor_cached: usize align(cache_line) = 0,

        pub fn send(self: *@This(), item: T) bool {
            const pushcur = self.write_cursor.load(.monotonic);
            if (pushcur - self.read_cursor_cached == capacity) {
                self.read_cursor_cached = self.read_cursor.load(.acquire);
                if (pushcur - self.read_cursor_cached == capacity) {
                    return false;
                }
            }
            self.ring[pushcur & cap_mask] = item;
            _ = self.write_cursor.fetchAdd(1, .release);
            return true;
        }

        pub fn receive(self: *@This()) ?T {
            const popcur = self.read_cursor.load(.monotonic);
            if (popcur == self.write_cursor_cached) {
                self.write_cursor_cached = self.write_cursor.load(.acquire);
                if (popcur == self.write_cursor_cached) {
                    return null;
                }
            }
            const item = self.ring[popcur & cap_mask];
            _ = self.read_cursor.fetchAdd(1, .release);
            return item;
        }
    };
}
