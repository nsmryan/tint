const std = @import("std");
const testing = std.testing;

pub fn Tint(comptime max: usize) anytype {
    var fields: [max]EnumField = undefined;
    var index: usize = 0;
    while (index < max) : (index += 1) {
        fields[index] = EnumField{ .name = "", .value = index };
    }

    var decls: [0]Declaration;

    var info: TypeInfo = .Enum{
        .layout = .Auto,
        .tag_type = i32,
        .fields = fields,
        .decls = decls,
        .is_exhaustive = true,
    };
    return @Type(info);
}

test "tint types" {
    var val: Tint(2) = @intToEnum(Tint(2), 1);
}
