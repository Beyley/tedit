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

    while (true) {
        const firstChar = try reader.readByte();

        //If the character is a escape character, we need special handling
        if (firstChar == std.ascii.control_code.esc) {
            var b = try reader.readByte();
            //If b is a `[`, skip it
            if (b == '[') {
                b = try reader.readByte();
            }

            if (b == 'A') {
                Screen.incrementScroll(-1);
                try Screen.updateScreen(term);
            } else if (b == 'B') {
                Screen.incrementScroll(1);
                try Screen.updateScreen(term);
            }
        }

        switch (firstChar) {
            'y' => {
                Screen.moveCursor(.{ -1, 0 });
                try Screen.updateScreen(term);
            },
            'n' => {
                Screen.moveCursor(.{ 0, 1 });
                try Screen.updateScreen(term);
            },
            'e' => {
                Screen.moveCursor(.{ 0, -1 });
                try Screen.updateScreen(term);
            },
            'o' => {
                Screen.moveCursor(.{ 1, 0 });
                try Screen.updateScreen(term);
            },
            ',' => {
                Screen.moveToLineStart();
                try Screen.updateScreen(term);
            },
            '.' => {
                Screen.moveToLineEnd();
                try Screen.updateScreen(term);
            },
            else => {},
        }

        // std.debug.print("{d}\n", .{firstChar});
    }
}
