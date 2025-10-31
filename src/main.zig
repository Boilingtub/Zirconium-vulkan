const std = @import("std");
const Zr = @import("Zirconium");

pub fn main() !void {
    try Zr.print("Zirconium Startup");
    try Zr.init();
}
