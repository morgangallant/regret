const std = @import("std");

pub const rps = @import("rps.zig");
pub const kuhn = @import("kuhn.zig");

test {
    std.testing.refAllDecls(@This());
}
