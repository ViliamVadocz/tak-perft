pub const Color = enum(u1) {
    White = 0,
    Black = 1,

    pub fn next(self: Color) Color {
        return switch (self) {
            .White => .Black,
            .Black => .White,
        };
    }

    pub fn advance(self: *Color) void {
        self.* = self.next();
    }
};
