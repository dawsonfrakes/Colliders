Vector2 :: struct { x, y: float32; }
Vector3 :: struct { x, y, z: float32; }
Vector4 :: struct { x, y, z, w: float32; }
Matrix4 :: struct { #as members : [16] float32; }

operator * :: (a: Matrix4, b: Matrix4) -> Matrix4 #no_context {
    result : Matrix4;
    for i: 0..3 for j: 0..3 for k: 0..3
        result.members[i * 4 + j] +=
            b.members[i * 4 + k] * a.members[k * 4 + j];
    return result;
}

CPU_Endianness :: enum u32 {
	UNKNOWN :: 0;
	LITTLE :: 1;
	BIG :: 2;
}

ENDIAN :: #run -> CPU_Endianness {
	if #complete CPU == {
	case .UNINITIALIZED; #through;
	case .KRAMPU; #through;
	case .CUSTOM;
		return .UNKNOWN;
	case .X64; #through;
	case .ARM64;
		return .LITTLE;
	}
}

native_to_little :: inline (x: $T) -> T {
	return ifx ENDIAN == .LITTLE x else BitOps.byte_swap(x);
}

native_to_big :: inline (x: $T) -> T {
	return ifx ENDIAN == .BIG x else BitOps.byte_swap(x);
}

ascii_to_utf16le_string_literal :: ($s: string) -> []u16 {
	utf16le : [s.count + 1]u16;
	for 0..s.count - 1 utf16le[it] = native_to_little(cast(u16) s[it]);
	return utf16le;
}

min :: inline (x: $T, y: T) -> T #no_context {
	return ifx x < y then x else y;
}

max :: inline (x: $T, y: T) -> T #no_context {
	return ifx x > y then x else y;
}

abs :: inline (x: $T) -> T #no_context {
	return ifx x >= 0 then x else -x;
}

clamp :: inline (x: $T, low: T, high: T) -> T #no_context {
    return max(low, min(x, high));
}

get_field_offset :: ($T: Type, name: string) -> s64 {
    info := type_info(T);
    for info.members {
        if it.name == name return it.offset_in_bytes;
    }
    return -1;
}

get_field_type :: ($T: Type, name: string) -> Type {
    info := type_info(T);
    for info.members {
        if it.name == name return Compiler.get_type(it.type);
    }
    return Type;
}

set_field :: inline (x: *$T, $name: string, value: $R) {
    #assert R == #run get_field_type(T, name);
    y :: #run get_field_offset(T, name);
    #assert y != -1;
    #insert #run Basic.tprint("<< (cast(*type_of(T.%)) (cast(*u8) x + y)) = value;", name);
}

#scope_file

Basic :: #import "Basic";
BitOps :: #import "Bit_Operations";
Compiler :: #import "Compiler";
