const std = @import("std");
const Screen = @import("screen.zig");

pub const Sequences = struct {
    pub const ClearScreen = "[2J";
    pub const MoveCursor = "[{d};{d}H";
    pub const CursorHome = "[H";
};

pub inline fn sendEscapeSequence(writer: anytype, comptime fmt: []const u8, extra_args: anytype) !void {
    try std.fmt.format(writer, "{c}" ++ fmt, .{std.ascii.control_code.esc} ++ extra_args);
}

const c = @cImport({
    @cInclude("sys/ioctl.h");
    @cInclude("signal.h");
});

var term: std.fs.File = undefined;

pub fn init(file: std.fs.File) !void {
    term = file;

    Screen.screen_update_mutex.lock();
    Screen.terminal_size = try getTerminalSize();
    Screen.screen_update_mutex.unlock();

    var ret: std.os.linux.E = @enumFromInt(c.sigaction(c.SIGWINCH, &c.struct_sigaction{
        .__sigaction_handler = .{
            .sa_handler = &sigwinchHandler,
        },
        .sa_flags = 0,
        .sa_mask = .{
            .__val = std.mem.zeroes([16]c_ulong),
        },
        .sa_restorer = null,
    }, null));

    switch (ret) {
        .SUCCESS => {},
        .FAULT => return error.SignalHandlerFault,
        .INVAL => return error.InvalidSignal,
        else => return error.UnknownSignalHandlerError,
    }
}

fn sigwinchHandler(signal: c_int) callconv(.C) void {
    if (signal != c.SIGWINCH) {
        return;
    }

    Screen.screen_update_mutex.lock();
    Screen.terminal_size = getTerminalSize() catch unreachable;
    Screen.screen_update_mutex.unlock();

    Screen.updateScreen(term) catch unreachable;
}

pub fn getTerminalSize() !Screen.TerminalSize {
    var size: c.winsize = undefined;
    var ret: std.os.linux.E = @enumFromInt(c.ioctl(term.handle, c.TIOCGWINSZ, &size));
    return switch (ret) {
        .SUCCESS => .{ .x = @intCast(size.ws_col), .y = @intCast(size.ws_row) },
        .INVAL => error.InvalidParameter,
        .NOTTY => error.BadFile,
        .PERM => error.NoPerms,
        else => error.UnknownIoctlError,
    };
}
