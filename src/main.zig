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
//pub fn Capped(comptime max: usize) type {
//    var fields: [max]EnumField = undefined;
//
//    // try to build enum fields at compile time?
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

pub fn Tagged(comptime T: type, comptime Tag: type, tag: Tag) type {
    return struct {
        const Self = This();

        const tag: Tag = tag;

        value: T,

        pub fn tagged(item: T) Tagged(T, Tag, tag) {
            return Tagged(T, Tag, tag){ .value = item };
        }

        pub fn untag(item: Tagged(T, Tag, tag)) T {
            return item.value;
        }

        pub fn get_tag(item: Tagged(T, Tag, tag)) Tag {
            return tag;
        }
    };
}

// I have not found a way to pass unknown tag information into a function.
fn entype(comptime T: type, tagged: Tagged(T, TypeInfo, _)) type {
    return @Type(tag);
}

test "tagged" {
    var tagged: Tagged(u32, u8, 1) = Tagged(u32, u8, 1).tagged(10);

    // the value inside the Tagged is availble
    {
        const expected: u32 = 10;
        expectEqual(expected, tagged.untag());
    }

    // the tag itself can be retrieved
    {
        const expected: u8 = 1;
        expectEqual(expected, tagged.get_tag());
    }

    var type_tag: Tagged(u32, TypeInfo, @typeInfo(u32)) = undefined;
    // we can initial without repeating the type this way...
    type_tag = @TypeOf(type_tag).tagged(100);

    // NOTE there does not seem to be a way to do this...
    //var typed: entype(u32, type_tag) = undefined;
}

pub fn TypeTagged(comptime T: type, comptime Tag: type) type {
    return struct {
        const Self = @This();

        tag: [0]Tag = undefined,

        value: T,

        pub fn tagged(item: T) TypeTagged(T, Tag) {
            return TypeTagged(T, Tag){ .value = item };
        }

        pub fn untag(item: TypeTagged(T, Tag)) T {
            return item.value;
        }

        // NOTE dubious
        pub fn get_tag(item: Self) type {
            return @typeInfo(@Type(item.tag)).Array.child;
        }
    };
}

// Partial type application is simply a function definition with comptime parameters
fn Tagi8(comptime T: type) type {
    return TypeTagged(T, i8);
}

test "type tagged" {
    var tagged: TypeTagged(u32, i8) = TypeTagged(u32, i8).tagged(128);

    // Typedefs are as easy as assignment- very nice.
    const TypedefTag = TypeTagged(u32, i8);
    var tagged2: TypedefTag = TypedefTag.tagged(128);

    expectEqual(tagged.untag(), tagged2.untag());

    // The tag does not increase the size of the type, as it is a 0 sized array.
    expectEqual(@sizeOf(u32), @sizeOf(TypedefTag));

    // NOTE These don't appear to work.
    //expectEqual(@typeInfo(i8), @typeInfo(tagged.get_tag()));
    //expectEqual(@typeInfo(i8), @typeInfo(@TypeOf(TypedefTag.tag)));

    // try out the TypeTagged type partially applied to i8 as the tag.
    var i8_tagged: Tagi8(u32) = Tagi8(u32){ .value = 1 };
}
