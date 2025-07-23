const std = @import("std");
const HashType = @import("zobrist.zig").HashType;

pub const Entry = struct {
    positions: u64,

    // The lower 8 bits will be used for the depth.
    // For this to work we need the table size to be
    // a power of two and larger than 256. (See checks below.)
    signature_and_depth: HashType,

    fn getDepth(self: Entry) u8 {
        return @intCast(self.signature_and_depth & 0xFF);
    }

    fn getHash(self: Entry, table_index: usize) HashType {
        // NOTE: We could do (table_index & 0xFF) but it's not needed
        // since the overlapping bits are the same.
        return ((self.signature_and_depth >> 8) << 8) | table_index;
    }

    fn setSignatureAndDepth(self: *Entry, hash: HashType, depth: u8) void {
        self.signature_and_depth = ((hash >> 8) << 8) | depth;
    }
};

pub const Bucket = [bucket_size]Entry;
// NOTE: depth 0 will always get replaced.
// There is no valid way to get a depth 0 otherwise,
// since perft(depth=0) returns 1 and never checks the table.
pub const init_bucket = [_]Entry{.{ .positions = 0, .signature_and_depth = 0 }} ** bucket_size;
pub const bucket_size = 2;

pub const Table = [size]Bucket;
pub const size = 1 << 28; // TODO: Experiment with different sizes
comptime {
    if (@popCount(@as(u64, size)) != 1) @compileError("Transposition table size should be a power of two");
    if (size < 256) @compileError("The size should take at least 8 bits so that we can squish the signature and depth together");
}

pub fn get(table: *Table, hash: HashType, depth: u8) ?u64 {
    const index = hash % table.len;
    const bucket = table.*[index];
    inline for (bucket) |entry| {
        if (entry.getDepth() == depth and entry.getHash(index) == hash) return entry.positions;
    }
    return null;
}

pub fn save(table: *Table, hash: HashType, positions: u64, depth: u8) void {
    const index = hash % table.len;
    const bucket = &table.*[index];
    inline for (0..bucket_size) |i| {
        const entry = &bucket[i];
        if (depth >= entry.getDepth()) {
            // replace with higher-up node
            entry.positions = positions;
            entry.setSignatureAndDepth(hash, depth);
            return;
        }
    }
    // replace last one in bucket (since we fill front to back)
    const last = &bucket[bucket.len - 1];
    last.positions = positions;
    last.setSignatureAndDepth(hash, depth);
}
