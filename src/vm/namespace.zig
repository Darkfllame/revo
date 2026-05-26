const std = @import("std");
const revo = @import("revo");

pub const NamespaceID = usize;

pub const Namespace = struct {
    path: []const u8,
    exports: revo.memory.TableID,
};

pub const NamespacePool = struct {
    alloc: std.mem.Allocator,
    namespaces: std.ArrayList(?Namespace),
    marks: std.DynamicBitSet,
    dead: std.ArrayList(NamespaceID),

    pub fn init(alloc: std.mem.Allocator) !NamespacePool {
        return .{
            .alloc = alloc,
            .namespaces = try std.ArrayList(?Namespace).initCapacity(alloc, 4),
            .marks = try std.DynamicBitSet.initEmpty(alloc, 64),
            .dead = try std.ArrayList(NamespaceID).initCapacity(alloc, 0),
        };
    }

    pub fn deinit(self: *NamespacePool) void {
        for (self.namespaces.items) |*maybe_ns| {
            if (maybe_ns.*) |*ns| self.alloc.free(ns.path);
        }
        self.namespaces.deinit(self.alloc);
        self.marks.deinit();
        self.dead.deinit(self.alloc);
    }

    pub fn create(self: *NamespacePool, path: []const u8, exports: revo.memory.TableID) !NamespaceID {
        const owned_path = try self.alloc.dupe(u8, path);
        errdefer self.alloc.free(owned_path);

        if (self.dead.pop()) |id| {
            self.namespaces.items[id] = .{
                .path = owned_path,
                .exports = exports,
            };
            return id;
        }

        const id: NamespaceID = @intCast(self.namespaces.items.len);
        try self.namespaces.append(self.alloc, .{
            .path = owned_path,
            .exports = exports,
        });
        if (id >= self.marks.capacity()) {
            try self.marks.resize(self.namespaces.items.len, false);
        }
        return id;
    }

    pub fn get(self: *NamespacePool, id: NamespaceID) !*Namespace {
        if (id >= self.namespaces.items.len) return error.InvalidNamespace;
        if (self.namespaces.items[id]) |*ns| return ns;
        return error.InvalidNamespace;
    }

    pub fn mark(self: *NamespacePool, id: NamespaceID, vm: *revo.VM) void {
        if (id >= self.namespaces.items.len) return;
        if (self.namespaces.items[id] == null) return;
        if (self.marks.isSet(id)) return;
        self.marks.set(id);
        vm.pushMarkNamespace(id);
    }

    pub fn sweep(self: *NamespacePool) void {
        const max_dead = self.namespaces.items.len;
        self.dead.ensureTotalCapacity(self.alloc, max_dead) catch return;
        self.dead.items.len = 0;
        for (self.namespaces.items, 0..) |*maybe_ns, idx| {
            if (maybe_ns.* == null) continue;
            if (self.marks.isSet(idx)) continue;
            self.alloc.free(maybe_ns.*.?.path);
            maybe_ns.* = null;
            self.dead.appendAssumeCapacity(@intCast(idx));
        }
        self.marks.unmanaged.unsetAll();
    }

    pub fn sweepStep(self: *NamespacePool, cursor: usize, limit: usize) usize {
        if (cursor >= self.namespaces.items.len) return 0;
        const end = @min(cursor + limit, self.namespaces.items.len);
        var processed: usize = 0;
        var i = cursor;
        while (i < end) : (i += 1) {
            processed += 1;
            const maybe_ns = self.namespaces.items[i];
            if (maybe_ns == null) continue;
            if (self.marks.isSet(i)) continue;
            self.alloc.free(maybe_ns.?.path);
            self.namespaces.items[i] = null;
            self.dead.append(self.alloc, @intCast(i)) catch {};
        }
        return processed;
    }

    pub fn clearMarks(self: *NamespacePool) void {
        self.marks.unmanaged.unsetAll();
    }

    pub fn capacity(self: *const NamespacePool) usize {
        return self.namespaces.items.len;
    }

    pub fn bytes(self: *const NamespacePool) usize {
        var total: usize = 0;
        for (self.namespaces.items) |maybe_ns| {
            if (maybe_ns) |ns| total += ns.path.len + @sizeOf(Namespace);
        }
        return total;
    }
};
