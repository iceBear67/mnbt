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
  let gzipWriter = @gzip.Writer::new(result)
  
  let uncompressed = @buffer.new()
  write_uncompressed(littleEndian~, tag, uncompressed)
  let slice = @io.Slice::new(uncompressed.to_bytes().to_array())

  let (_, err) = gzipWriter.write(slice)
  guard gzipWriter.close() is None
  let r = match err {
    None => result
    Some(e) => raise e
  }
  return r
}

///|
/// This method serializes a valid @nbt.NBTTag into given buffer with ZLib compression.
/// see also: write_uncompressed
pub fn write_zlib(
  littleEndian? : Bool = false,
  dict?: @io.Slice[Byte] = @io.Slice::new([]),
  tag : @nbt.NBTTag,
) -> @io.Buffer raise {
  let nbtBuf = @buffer.new()
  write_uncompressed(littleEndian~, tag, nbtBuf)

  let result = @io.Buffer::new()
  let zlibw = @zlib.Writer::new_dict(result, dict)

  // let buf = @io.Buffer::from_bytes(nbtBuf.contents())
  guard zlibw.write(@io.Slice::new(nbtBuf.contents().to_array())) is (_, None)
  // guard @io.copy(zlibw, buf) is (_, None)
  guard zlibw.close() is None
  result
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
