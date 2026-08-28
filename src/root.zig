const std = @import("std");

pub const rps = @import("rps.zig");

test {
    std.testing.refAllDecls(@This());
}
