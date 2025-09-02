// NBT Parser and Writer for NBT binary format.

///|
pub suberror UnknownTagType String

///|
/// This serializes a valid@nbt.NBTTag object into the given buffer.
/// All NBT files created by Minecraft have either a [NBT Compound / JSON Object] compound or 
/// sometimes a [NBT List / JSON Array] list‌[Bedrock Edition only] as the root tag, this tag has a name but is often the empty string.
/// To write a NBT Tag that minecraft can parse, please make sure there is a root node like that.
pub fn write_uncompressed(
  littleEndian? : Bool = false,
  tag : @nbt.NBTTag,
  buf : @buffer.T,
) -> Unit {
  write(tag, WriterByteBuf::{ littleEndian, buffer: buf })
}

///|
fn write_compound(tag : @nbt.NBTTag, out : WriterByteBuf) -> Unit {
  match tag {
    TagCompound(name, map) => {
      for _, entry in map.iter() {
        let (key, value) = entry
        let tagType = value.to_type_id()
        out.write_byte(value.to_type_id())
        out.write_string(key)
        if tagType == @nbt.TypeCompound {
          write_compound(value, out)
          continue
        } else {
          write(with_type=false, value, out)
        }
      }
      write(@nbt.NBTTag::TagEnd, out)
    }
    _ => return
  }
}

///|
fn write(
  with_type? : Bool = true,
  tag : @nbt.NBTTag,
  out : WriterByteBuf,
) -> Unit {
  if with_type {
    out.write_byte(tag.to_type_id())
  }
  match tag {
    TagIntArray(iarr) => {
      out.write_int(iarr.length())
      for i in iarr {
        out.write_int(i)
      }
    }
    TagCompound(name, map) => {
      out.write_string(name)
      write_compound(tag, out)
    }
    TagList(comT, l) => {
      out.write_byte(comT)
      out.write_int(l.length())
      for i in l {
        write(with_type=false, i, out)
      }
    }
    TagString(s) => out.write_string(s)
    TagByteArray(b) => {
      out.write_int(b.length())
      out.write_bytes(b)
    }
    TagDouble(d) => out.write_uint64(d.reinterpret_as_uint64())
    TagFloat(f) => out.write_uint(f.reinterpret_as_uint())
    TagLong(l) => out.write_int64(l)
    TagInt(i) => out.write_int(i)
    TagShort(s) => out.write_uint16(s.reinterpret_as_uint16())
    TagByte(b) => out.write_byte(b)
    TagEnd => ()
    TagLongArray(larr) => {
      out.write_int(larr.length())
      for i in larr {
        out.write_int64(i)
      }
    }
  }
}

///|
fn WriterByteBuf::write_string(self : WriterByteBuf, str : String) -> Unit {
  self.write_uint16(str.length().to_uint16()) // todo overflow check
  if str.length() == 0 {
    return
  }
  let utf = @encoding.encode(UTF8, str)
  self.write_bytes(utf[:utf.length()]) // strip the null character
}
