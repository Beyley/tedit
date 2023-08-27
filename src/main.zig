const std = @import("std");
const vt100 = @import("vt100.zig");
const Screen = @import("screen.zig");

pub fn main() !void {
    var term = std.io.getStdOut();
    var writer = term.writer();
    //At the end of the app, just dump a \n to make the terminal happy
    defer writer.writeAll("\n") catch unreachable;

    var stdin = std.io.getStdIn();
    var reader = stdin.reader();

    Screen.screen_update_mutex = std.Thread.Mutex{};
    try vt100.init(term);

    const filename = "src/screen.zig";

    var file = try std.fs.cwd().openFile(filename, .{});
    try Screen.loadFile(file, filename);
    file.close();

    try Screen.updateScreen(term);

    _ = try reader.readByte();
}
