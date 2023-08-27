const std = @import("std");
const vt100 = @import("vt100.zig");

pub const TerminalSize = extern struct { x: u32, y: u32 };

pub var terminal_size: TerminalSize = undefined;
pub var screen_update_mutex: std.Thread.Mutex = undefined;
pub var scroll: usize = 3;

var file_name: ?[]const u8 = null;
var file_contents: ?std.ArrayList(u8) = null;

pub fn loadFile(file: std.fs.File, filename: []const u8) !void {
    var allocator = std.heap.c_allocator;

    if (file_contents) |*file_to_clear| {
        file_to_clear.clearRetainingCapacity();
    } else {
        file_contents = std.ArrayList(u8).init(allocator);
    }

    if (file_name) |old_name| {
        allocator.free(old_name);
    }

    file_name = try allocator.dupe(u8, filename);

    var buf: [4096]u8 = undefined;
    var read = try file.read(&buf);
    while (read > 0) : (read = try file.read(&buf)) {
        try file_contents.?.appendSlice(buf[0..read]);
    }
}

pub fn updateScreen(term: std.fs.File) !void {
    screen_update_mutex.lock();
    defer screen_update_mutex.unlock();

    var buffered_writer = std.io.bufferedWriter(term.writer());
    var writer = buffered_writer.writer();

    //Clear the screen, and go to the top left
    try vt100.sendEscapeSequence(writer, vt100.Sequences.ClearScreen, .{});
    try vt100.sendEscapeSequence(writer, vt100.Sequences.CursorHome, .{});

    const header_size = 1;
    const header_char = "█";
    _ = header_char;

    //Write a header
    var header_written: usize = 0;
    try writer.writeAll("▞");
    header_written += 1;
    if (file_name) |name| {
        try writer.writeAll(name);
        header_written += name.len;

        try writer.writeAll("▚ ");
        header_written += 2;
    }
    const start_offset = header_written;
    for (header_written..terminal_size.x) |i| {
        var idx = (i - start_offset + 7) % 14;

        try writer.writeAll(switch (idx) {
            0 => "▁",
            1 => "▂",
            2 => "▃",
            3 => "▄",
            4 => "▅",
            5 => "▆",
            6 => "▇",
            7 => "█",
            8 => "▇",
            9 => "▆",
            10 => "▅",
            11 => "▄",
            12 => "▃",
            13 => "▂",
            else => unreachable,
        });
        header_written += 1;
    }

    //Go to the second row
    try vt100.sendEscapeSequence(writer, vt100.Sequences.MoveCursor, .{ 2, 1 });

    if (file_contents) |file| {
        var stream = std.io.fixedBufferStream(file.items);
        var reader = stream.reader();

        var scroll_to_go: usize = scroll;
        var chars_in_line: usize = 0;
        var lines_written: usize = 0;
        blk: {
            //While we still have bytes left to scroll
            while (scroll_to_go > 0) {
                //Read a byte, break out if EOF
                var b: u8 = reader.readByte() catch |err| {
                    if (err == error.EndOfStream) break :blk else return err;
                };

                //If the byte is a newline
                if (b == '\n') {
                    //We are gonna scroll one less byte
                    scroll_to_go -= 1;
                }
            }

            while (true) {
                var b: u8 = reader.readByte() catch |err| {
                    if (err == error.EndOfStream) {
                        break;
                    } else return err;
                };

                //Ignore \r
                if (b == '\r') {
                    continue;
                }

                //If we reach a newline
                if (b == '\n') {
                    //Reset the amount of chars we have written in this line
                    chars_in_line = 0;
                    //Up the amount of lines we have written
                    lines_written += 1;

                    //Break out if we are printing the last line that will fit
                    if (lines_written == terminal_size.y - header_size) {
                        break :blk;
                    }
                }

                chars_in_line += 1;

                if (chars_in_line == terminal_size.x + 1) {
                    try writer.writeAll(" $");
                } else if (chars_in_line < terminal_size.x) {
                    try writer.writeByte(b);
                }
            }
        }
    }

    try buffered_writer.flush();
}
