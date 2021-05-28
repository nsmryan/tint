const std = @import("std");

const testing = std.testing;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const TypeInfo = std.builtin.TypeInfo;
const Enum = std.builtin.TypeInfo.Enum;
const EnumField = std.builtin.TypeInfo.EnumField;
const Declaration = std.builtin.TypeInfo.Declaration;

// This will not work due to issue 2907, which forbids Enums being created from
// @Type. This is an understandable limitation.
//pub fn Capped(comptime max: usize) type l2
//    var fields: [max]EnumField = undefined;
//    var index: usize = 0;
//    while (index < max) : (index += 1) {
//        fields[index] = EnumField{ .name = "", .value = index };
//    }
//    const enum_fields = fields[0..];
//
//    const decls: [0]Declaration = undefined;
//
//    var info: TypeInfo = TypeInfo{
//        .Enum = Enum{
//            .layout = .Auto,
//            .tag_type = i32,
//            .fields = enum_fields,
//            .decls = decls[0..],
//            .is_exhaustive = true,
//        },
//    };
//    return @Type(info);
//}

//test "tint enum types" {
//    var val: Capped(2) = @intToEnum(Capped(2), 1);
//}

// Instead, lets just use an associated type to store the max value.
pub fn Capped(comptime T: type, comptime max: T) type {
    return struct {
        const Self = @This();
        const cap: T = max;
        value: T,

        pub fn create(val: T) Self {
            return Capped(T, max){ .value = val };
        }

        pub fn add(self: Self, other: Self) Self {
            return Capped(T, Self.cap).create((self.value + other.value) % Self.cap);
        }

        pub fn mult(self: Self, other: Self) Self {
            return Capped(T, Self.cap).create((self.value * other.value) % Self.cap);
        }

        pub fn div(self: Self, other: Self) Self {
            return Capped(T, Self.cap).create(self.value / other.value);
        }

        pub fn sub(self: Self, other: Self) Self {
            return Capped(T, Self.cap).create((Self.cap + self.value - other.value) % Self.cap);
        }
    };
}

test "tint associated type" {
    var five: Capped(usize, 10) = Capped(usize, 10).create(5);

    const expected_value: usize = 5;
    expectEqual(expected_value, five.value);

    const expected_max: usize = 10;
    expectEqual(expected_max, Capped(usize, 10).cap);

    var two: Capped(usize, 10) = Capped(usize, 10).create(2);

    var seven = five.add(two);
    {
        const expected_sum: usize = 7;
        expectEqual(expected_sum, seven.value);
    }

    var rollover = seven.add(five);
    {
        const expected_sum: usize = 2;
        expectEqual(expected_sum, rollover.value);
    }

    {
        var mult = seven.mult(five);
        const expected_sum: usize = 5;
        expectEqual(expected_sum, mult.value);
    }

    {
        var div = seven.div(five);
        const expected_sum: usize = 1;
        expectEqual(expected_sum, div.value);
    }

    {
        var sub = seven.sub(five);
        const expected_sum: usize = 2;
        expectEqual(expected_sum, sub.value);
    }

    {
        var sub = five.sub(seven);
        const expected_sum: usize = 8;
        expectEqual(expected_sum, sub.value);
    }

    // Capped does not add data to the type
    expectEqual(@sizeOf(u32), @sizeOf(Capped(u32, 10)));
}
