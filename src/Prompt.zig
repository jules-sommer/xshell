const std = @import("std");
const Context = @import("Context.zig");
const ChildProcess = std.process.Child;

/// This function is currently where the shell decides
/// which prompt to use. This exists because instead of
/// having a prompt that was brutally minimalist until
/// i got around to making a nicer one, I simply decided
/// to call the starship binary to get a fully featured
/// prompt for now. Presumably in the future this will
/// decide based on config what prompt to display.
///
pub fn prompt(ctx: *Context) !void {
    try ctx.out.writeAll(try runStarshipPrompt(ctx));
    // _ = try ctx.out().write("$ ");
}

pub fn runStarshipPrompt(ctx: *Context) ![]const u8 {
    // Define the command and its arguments
    const command = "starship";
    var path_buf: [255]u8 = undefined;
    const abs_path_cwd = ctx.cwd.realpath(".", &path_buf) catch @panic("need path");
    var path_arg = try std.mem.concat(ctx.allocator(), u8, &[_][]const u8{ "--logical-path=", abs_path_cwd });

    const args = [_][]const u8{
        "prompt",
        "--status=0",
        "--jobs=0",
        path_arg[0..],
        "--cmd-duration=30",
    };

    // Allocate memory for the array of slices
    const starship_args = try ctx.allocator().alloc([]const u8, args.len + 1);

    // Copy the command and arguments into the allocated memory
    starship_args[0] = try ctx.allocator().dupe(u8, command);
    for (args, 0..) |arg, i| {
        starship_args[i + 1] = try ctx.allocator().dupe(u8, arg);
    }

    std.debug.print("{s}", .{starship_args});

    var child = ChildProcess.init(starship_args, ctx.allocator());
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    var child_stdout, var child_stderr = .{
        try std.ArrayList(u8).initCapacity(ctx.allocator(), 1024),
        try std.ArrayList(u8).initCapacity(ctx.allocator(), 1024),
    };

    try child.spawn();
    try child.collectOutput(&child_stdout, &child_stderr, 1024 * 1024);

    switch (try child.wait()) {
        .Exited => |code| if (code == 0) {
            return child_stdout.toOwnedSlice();
        } else {
            return error.OtherError;
        },
        .Signal, .Stopped => |sig| {
            std.debug.print("sig/stopped: {}", .{sig});
            return error.OtherError;
        },
        .Unknown => {
            std.debug.print("unknown", .{});
            return error.OtherError;
        },
    }
}
