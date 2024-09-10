//! `Context` provides the shell with globally required data
//! and methods including StdIo (in,out,err,etc), an arena
//! allocator that is freed every prompt/interpreter/execute
//! loop and serves as a scratch buffer of sorts, as well
//! as methods to manage these items.

const std = @import("std");
const File = std.fs.File;
const Reader = File.Reader;
const Writer = File.Writer;
const mecha = @import("mecha");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;

backing_allocator: Allocator,
arena: ArenaAllocator,

out: *Writer,
err: *Writer,
in: *Reader,

cwd: std.fs.Dir = std.fs.cwd(),
status: u8 = 0,
duration: u32 = 0,

const Ctx = @This();

pub fn init(backing_allocator: Allocator) !*Ctx {
    var stdin = std.io.getStdIn().reader();
    var stdout = std.io.getStdOut().writer();
    var stderr = std.io.getStdErr().writer();

    var arena = ArenaAllocator.init(backing_allocator);
    const arena_alloc = arena.allocator();
    _ = arena_alloc; // autofix

    // spawn our context on the backing allocator so the arena can be freed regularly
    const context = blk: {
        const context_ptr = try backing_allocator.create(Ctx);

        context_ptr.* = .{
            .backing_allocator = backing_allocator,
            .arena = arena,

            .in = &stdin,
            .out = &stdout,
            .err = &stderr,
        };

        break :blk context_ptr;
    };

    return context;
}

pub fn allocator(self: *Ctx) Allocator {
    return self.arena.allocator();
}

pub fn deinit(self: *Ctx) void {
    defer self.backing_allocator.destroy(self);
    self.arena.deinit();
}
