pub const Color = enum(u1) {
    White = 0,
    Black = 1,

    fn next(self: Color) Color {
        return switch (self) {
            .White => .Black,
            .Black => .White,
        };
    }
};
