///|
struct WriterByteBuf {
  littleEndian : Bool
  buffer : @buffer.T
}

///|
pub fn newWriter(littleEndian : Bool, buffer : @buffer.T) -> WriterByteBuf {
  WriterByteBuf::{ littleEndian, buffer }
}

///|
pub fn WriterByteBuf::write_int(self : WriterByteBuf, i : Int) -> Unit {
  if self.littleEndian {
    self.buffer.write_int_le(i)
  } else {
    self.buffer.write_int_be(i)
  }
}

///|
pub fn WriterByteBuf::write_int64(self : WriterByteBuf, i : Int64) -> Unit {
  if self.littleEndian {
    self.buffer.write_int64_le(i)
  } else {
    self.buffer.write_int64_be(i)
  }
}

///|
pub fn WriterByteBuf::write_uint(self : WriterByteBuf, i : UInt) -> Unit {
  if self.littleEndian {
    self.buffer.write_uint_le(i)
  } else {
    self.buffer.write_uint_be(i)
  }
}

///|
pub fn WriterByteBuf::write_uint64(self : WriterByteBuf, i : UInt64) -> Unit {
  if self.littleEndian {
    self.buffer.write_uint64_le(i)
  } else {
    self.buffer.write_uint64_be(i)
  }
}

///|
pub fn WriterByteBuf::write_uint16(self : WriterByteBuf, i : UInt16) -> Unit {
  if self.littleEndian {
    // little-endian: low byte first
    self.buffer.write_byte((i & 0xFF).to_byte())
    self.buffer.write_byte(((i >> 8) & 0xFF).to_byte())
  } else {
    // big-endian: high byte first
    self.buffer.write_byte(((i >> 8) & 0xFF).to_byte())
    self.buffer.write_byte((i & 0xFF).to_byte())
  }
}

///|
pub fn WriterByteBuf::write_bytes(
  self : WriterByteBuf,
  i : @bytes.View,
) -> Unit {
  self.buffer.write_bytes(i.to_bytes())
}

///|
pub fn WriterByteBuf::write_byte(self : WriterByteBuf, b : Byte) -> Unit {
  self.buffer.write_byte(b)
}

///|
fn WriterByteBuf::write_string(
  self : WriterByteBuf,
  str : String,
) -> Unit raise {
  if str.length() > @uint16.max_value.to_int() {
    raise fail(
      "The given String is longer than maximum length that NBT can hold (\{str.length()} > \{@uint16.max_value})",
    )
  }
  let utf = @encoding.encode(UTF8, str)
  self.write_uint16(utf.length().to_uint16())
  if utf.length() == 0 {
    return
  }
  self.write_bytes(utf[:utf.length()]) // strip the null character
}
