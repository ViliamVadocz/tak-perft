const std = @import("std");
const HashType = @import("zobrist.zig").HashType;

pub const Entry = packed struct {
    positions: u64,
    depth: u8,
    // We don't need the lower 8 bit since table size is power of two and at least 2^8 size.
    // The index where we are mapped gives us at least the lower 8 bits.
    signature: std.meta.Int(.unsigned, @bitSizeOf(HashType) - 8),

    fn getHash(entry: Entry, table_index: usize) HashType {
        return (entry.signature << 8) | table_index;
    }
};

pub const Bucket = [2]Entry;
pub const Table = [size]Bucket;
pub const size = 1 << 22; // TODO: Experiment with different sizes
comptime {
    if (@popCount(@as(u64, size)) != 1) @compileError("Transposition table size should be a power of two");
    if (size < 256) @compileError("The size should take at least 8 bits so that we can squish the signature and depth together");
}

pub fn get(table: *Table, hash: HashType, depth: u8) ?u64 {
    const index = hash % table.len;
    const bucket = table.*[index];
    inline for (bucket) |entry| {
        if (entry.depth == depth and entry.getHash(index) == hash) return entry.positions;
    }
    return null;
}

pub fn save(table: *Table, hash: HashType, positions: u64, depth: u8) void {
    const index = hash % table.len;
    const bucket = &table.*[index];
    for (bucket) |*entry| {
        if (entry.depth > depth) continue;
        // replace with higher-up node
        entry.positions = positions;
        entry.signature = @truncate(hash >> 8);
        entry.depth = depth;
        return;
    }
    // replace last one in bucket (since we fill front to back)
    const last = &bucket[bucket.len - 1];
    last.positions = positions;
    last.signature = @truncate(hash >> 8);
    last.depth = depth;
}
