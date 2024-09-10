const std = @import("std");
const ChildProcess = std.process.Child;
const File = std.fs.File;
const Prompt = @import("Prompt.zig");
const Allocator = std.mem.Allocator;
const GeneralPurposeAllocator = std.heap.GeneralPurposeAllocator;
const posix = std.posix;
const mecha = @import("mecha");
const Context = @import("Context.zig");

/// Default instantiation of a GeneralPurposeAllocator used
/// within the context.
pub const ThreadSafeGPA = std.heap.GeneralPurposeAllocator(.{
    .safety = true,
    .thread_safe = true,
    .enable_memory_limit = true,
});

fn getInputUntil(
    writer: anytype,
    buffer: *[1024]u8,
    delimiter: u8,
) ![]u8 {
    return try writer.readUntilDelimiter(buffer, delimiter);
}

fn resetForNextPrompt(writer: anytype) void {
    if (writer.write("\n") catch unreachable == 0) {
        @panic("failed to reset for next prompt");
    }
}

fn shell(ctx: *Context) !void {
    repl: while (true) {
        const max_input = 1024;

        try Prompt.prompt(ctx);

        // Read STDIN into buffer
        var input_buffer: [max_input]u8 = undefined;
        const input_str = (try ctx.in.readUntilDelimiterOrEof(input_buffer[0..], '\n')) orelse {
            // No input, probably CTRL-d (EOF). Print a newline and exit!
            try ctx.out.print("\n\n\n\nNO INPUT / EOF\n\n\n\nBuffer:{s}\n", .{input_buffer});
            break :repl;
        };

        // If the input starts with a ':' then we have to handle it as a
        // control sequence
        if (std.mem.startsWith(u8, input_str, ":")) {
            const control_seq = input_str[1..];

            // quit
            if (std.mem.eql(u8, control_seq, "q")) {
                std.debug.print("Exiting...", .{});
                break :repl;
            }
        }

        if (ctx.arena.reset(.{ .retain_with_limit = 4094 }) != true) {
            std.debug.print("Couldn't reset arena...", .{});
        }
    }
}

pub fn main() !void {
    var gpa = ThreadSafeGPA{};
    defer if (gpa.deinit() == .leak) @panic("GPA leaked memory...");
    gpa.setRequestedMemoryLimit(@sizeOf(u8) * 1024 * 1024 * 1024);

    const ctx = try Context.init(gpa.allocator());
    defer ctx.deinit();

    try shell(ctx);
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}
