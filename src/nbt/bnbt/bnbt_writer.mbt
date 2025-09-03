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
) -> Unit raise {
  write_with_type(tag, WriterByteBuf::{ littleEndian, buffer: buf })
}

///|
/// This serializes a valid @nbt.NBTTag into given buffer in GZip format.
/// This is the default format of Minecraft.
/// see also: write_uncompressed
pub fn write_gzip(
  littleEndian? : Bool = false,
  tag : @nbt.NBTTag,
) -> @io.Buffer raise {
  let result = @io.Buffer::new()
  let gzw = @gzip.Writer::new(result)
  let pipew = @buffer.new()
  write_uncompressed(littleEndian~, tag, pipew)
  let slice = @io.Slice::new(pipew.contents().to_array())
  let (_, err) = gzw.write(slice)
  match err {
    None => result
    Some(e) => raise e
  }
}

///|
/// This method serializes a valid @nbt.NBTTag into given buffer with ZLib compression.
/// see also: write_uncompressed
pub fn write_zlib(
  littleEndian? : Bool = false,
  tag : @nbt.NBTTag,
) -> @io.Buffer raise {
  let dict = @io.Slice::new([])
  let pipew = @io.Buffer::new()
  let nbtBuf = @buffer.new()
  write_uncompressed(littleEndian~, tag, nbtBuf)
  let buf = @io.Buffer::from_bytes(nbtBuf.contents())
  let zlibw = @zlib.Writer::new_dict(pipew, dict)
  let (_, err) = zlibw.write(buf.to_slice())
  if err != None {
    raise fail("Failed to compress ")
  }
  guard zlibw.close() is None
  buf
}

///|
pub fn write_compound(tag : @nbt.NBTTag, out : WriterByteBuf) -> Unit raise {
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
          write_with_type(with_type=false, value, out)
        }
      }
      write_with_type(@nbt.NBTTag::TagEnd, out)
    }
    _ => return
  }
}

///|
fn write_with_type(
  with_type? : Bool = true,
  tag : @nbt.NBTTag,
  out : WriterByteBuf,
) -> Unit raise {
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
        write_with_type(with_type=false, i, out)
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
