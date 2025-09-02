///|
suberror EndOfFile

///|
struct ReaderByteBuf {
  littleEndian : Bool
  mut readerIndex : Int
  bytes : @bytes.View
}

pub fn newReader(littleEndian: Bool, bytes: @bytes.View) -> ReaderByteBuf {
  ReaderByteBuf::{
    littleEndian, readerIndex: 0, bytes
  }
}

///|
pub fn ReaderByteBuf::remaining(self : ReaderByteBuf) -> Int {
  self.bytes.length() - self.readerIndex
}

///|
pub fn ReaderByteBuf::read_byte(self : ReaderByteBuf) -> Byte raise EndOfFile {
  guard self.remaining() >= 1 else { raise EndOfFile }
  let byte = self.bytes[self.readerIndex:self.readerIndex+1]
  self.readerIndex += 1
  byte[0]
}

///|
pub fn ReaderByteBuf::read_i16(self : ReaderByteBuf) -> Int16 raise EndOfFile {
  guard self.remaining() >= 2 else { raise EndOfFile }
  let bytes = self.bytes[self.readerIndex:self.readerIndex + 2]
  self.readerIndex += 2
  if self.littleEndian {
    return bytes[0].to_int16() + (bytes[1].to_int16() << 8 : Int16)
  } else {
    return bytes[1].to_int16() + (bytes[0].to_int16() << 8 : Int16)
  }
}

///|
pub fn ReaderByteBuf::read_i32(self : ReaderByteBuf) -> Int raise EndOfFile {
  guard self.remaining() >= 4 else { raise EndOfFile }
  let bytes = self.bytes[self.readerIndex:self.readerIndex + 4]
  self.readerIndex += 4
  if self.littleEndian {
    return bytes[0].to_int() +
      (bytes[1].to_int() << 8 : Int) +
      (bytes[2].to_int() << 16 : Int) +
      (bytes[3].to_int() << 24 : Int)
  } else {
    return bytes[3].to_int() +
      (bytes[2].to_int() << 8 : Int) +
      (bytes[1].to_int() << 16 : Int) +
      (bytes[0].to_int() << 24 : Int)
  }
}

///|
pub fn ReaderByteBuf::read_i64(self : ReaderByteBuf) -> Int64 raise EndOfFile {
  guard self.remaining() >= 8 else { raise EndOfFile }
  let bytes = self.bytes[self.readerIndex:self.readerIndex + 8]
  self.readerIndex += 8
  if self.littleEndian {
    return bytes[0].to_int64() +
      (bytes[1].to_int64() << 8 : Int64) +
      (bytes[2].to_int64() << 16 : Int64) +
      (bytes[3].to_int64() << 24 : Int64) +
      (bytes[4].to_int64() << 32 : Int64) +
      (bytes[5].to_int64() << 40 : Int64) +
      (bytes[6].to_int64() << 48 : Int64) +
      (bytes[7].to_int64() << 56 : Int64)
  } else {
    return bytes[7].to_int64() +
      (bytes[6].to_int64() << 8 : Int64) +
      (bytes[5].to_int64() << 16 : Int64) +
      (bytes[4].to_int64() << 24 : Int64) +
      (bytes[3].to_int64() << 32 : Int64) +
      (bytes[2].to_int64() << 40 : Int64) +
      (bytes[1].to_int64() << 48 : Int64) +
      (bytes[0].to_int64() << 56 : Int64)
  }
}

///|
pub fn ReaderByteBuf::read_byte_array(
  self : ReaderByteBuf,
  len : Int,
) -> @bytes.View raise EndOfFile {
  guard self.remaining() >= len else { raise EndOfFile }
  let result = self.bytes[self.readerIndex:self.readerIndex + len]
  self.readerIndex += len
  return result
}

///|
fn ReaderByteBuf::read_string(self : ReaderByteBuf) -> String raise {
  let lenName = self.read_i16().reinterpret_as_uint16()
  let name_arr = self.read_byte_array(lenName.to_int())
  @encoding.decoder(UTF8).decode(name_arr)
}
