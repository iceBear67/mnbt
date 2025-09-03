///|
/// This method probes which compression does the given tag uses then tries to parse them.
/// See also: parse_uncompressed
pub fn parse(littleEndian? : Bool = false, b : Bytes) -> @nbt.NBTTag raise {
  guard b.length() > 2 else { return parse_uncompressed(b[:], littleEndian~) }
  if b[0:2] == [0x1F, 0x8B] { // GZIP header
    return parse_gzip(littleEndian~, b)
  }
  // ZLib headers, usually begins with 78 which is obviously higher than all of NBT type ids.
  // 78 01 - No Compression/low
  // 78 5E - Fast Compression
  // 78 9C - Default Compression
  // 78 DA - Best Compression 
  if b[0] == 0x78 {
    return parse_zlib(b, littleEndian~)
  }
  return parse_uncompressed(littleEndian~, b)
}

///|
/// Parse gzipped binary NBT data to NBTTags.
/// By default, Minecraft compresses its tag in GZip.
pub fn parse_gzip(littleEndian? : Bool = false, b : Bytes) -> @nbt.NBTTag raise {
  let slice = @io.Slice::new(b.to_array())
  let (reader, err) = @gzip.Reader::new(@io.Buffer::from_bytes(b))
  if err is Some(e) {
    raise e
  }
  let result = @io.Buffer::new().to_slice()
  while true {
    let (readBytes, err) = reader.read(result)
    if err is Some(e) {
      raise e
    }
    if readBytes <= 0 {
      break
    }
  }
  parse_uncompressed(littleEndian~, result.to_bytes()[:])
}

///|
/// Parse zlib compressed binary NBT data to NBTTags.
/// See also: #parse_uncompressed
pub fn parse_zlib(littleEndian? : Bool = false, b : Bytes) -> @nbt.NBTTag raise {
  let inp = @io.Buffer::from_bytes(b)
  let dict = @io.Slice::new([])
  let (zr, err) = @zlib.Reader::new_dict(inp, dict)
  if err is Some(e) {
    raise e
  }
  let decompressed = @io.Buffer::new().to_slice()
  while true {
    let (readBytes, err) = zr.read(decompressed)
    guard err is None else { break }
    if readBytes <= 0 {
      break
    }
  }
  return parse_uncompressed(littleEndian~, decompressed.to_bytes()[:])
}

///|
/// Parses uncompressed binary NBT data to NBTTags.
/// @param littleEndian In Bedrock Edition, all numbers are encoded in little-endian.
/// By default, this method uses big endian, which corresponds to the default behaviour of MC: Java Edition.
/// 
/// @raise UnknownTagType, EndOfFile
pub fn parse_uncompressed(
  littleEndian? : Bool = false,
  input : @bytes.View,
) -> @nbt.NBTTag raise {
  let buf = ReaderByteBuf::{ readerIndex: 0, littleEndian, bytes: input }
  return parse(buf)
}

///|
/// This method parses a complete NBTTag from uncompressed byte stream.
/// 
/// A tag is an individual part of the data tree. 
/// The first byte in a tag is the tag type (ID), followed by a two byte big-endian unsigned 16-bit integer (ushort) for the length of the name,
/// then the name as a string in UTF-8 format (Note TAG_End is not named and does not contain the extra 2 bytes; the name is assumed to be empty). 
/// Finally, depending on the type of the tag, the bytes that follow are part of that tag's payload. 
/// 
pub fn parse(buf : ReaderByteBuf) -> @nbt.NBTTag raise {
  parse_as(buf, buf.read_byte())
}

///|
/// This method parses a NBTTag as the given type. The type byte is not read to allow
/// certain tag containers to parse their children recursively.
fn parse_as(buf : ReaderByteBuf, _type : Byte) -> @nbt.NBTTag raise {
  return match _type {
    @nbt.TypeEnd => @nbt.NBTTag::TagEnd
    @nbt.TypeByte => @nbt.NBTTag::TagByte(buf.read_byte())
    @nbt.TypeShort => @nbt.NBTTag::TagShort(buf.read_i16())
    @nbt.TypeInt => @nbt.NBTTag::TagInt(buf.read_i32())
    @nbt.TypeLong => @nbt.NBTTag::TagLong(buf.read_i64())
    @nbt.TypeFloat =>
      @nbt.NBTTag::TagFloat(buf.read_i32().reinterpret_as_float())
    @nbt.TypeDouble =>
      @nbt.NBTTag::TagDouble(buf.read_i64().reinterpret_as_double())
    @nbt.TypeByteArray => @nbt.NBTTag::TagByteArray(parse_byte_array(buf))
    @nbt.TypeString => @nbt.NBTTag::TagString(buf.read_string())
    @nbt.TypeList => parse_list(buf)
    @nbt.TypeIntArray => @nbt.NBTTag::TagIntArray(parse_list_int(buf))
    @nbt.TypeLongArray => @nbt.NBTTag::TagLongArray(parse_list_long(buf))
    @nbt.TypeCompound => {
      let name = buf.read_string()
      @nbt.TagCompound(name, parse_map(buf))
    }
    _ => raise UnknownTagType("Unknown tag type: " + _type.to_string())
  }
}

///|
/// This method reads a complete named tag from uncompressed byte stream.
fn parse_named_tag(buf : ReaderByteBuf) -> (String, @nbt.NBTTag) raise {
  let _type = buf.read_byte()
  if _type == @nbt.TypeEnd {
    return ("", @nbt.NBTTag::TagEnd)
  }
  let name = buf.read_string()
  if _type == @nbt.TypeCompound {
    return (name, @nbt.NBTTag::TagCompound(name, parse_map(buf))) // since the name is already parsed, we should parse payload directly.
  }
  return (name, parse_as(buf, _type))
}

///|
/// This method parses a CompoundTag from uncompressed byte stream.
fn parse_map(buf : ReaderByteBuf) -> Map[String, @nbt.NBTTag] raise {
  let map : Map[String, @nbt.NBTTag] = {}
  while true {
    let (name, tag) = parse_named_tag(buf)
    match tag {
      TagEnd => break
      _ => map[name] = tag
    }
  }
  map
}

///|
/// This method parses a ListTag from uncompressed byte stream.
fn parse_list(buf : ReaderByteBuf) -> @nbt.NBTTag raise {
  let component_type = buf.read_byte()
  let size = buf.read_i32()
  let result = if component_type == @nbt.TypeCompound {
    FixedArray::makei(size, _ => @nbt.NBTTag::TagCompound("", parse_map(buf)))
  } else {
    FixedArray::makei(size, _ => parse_as(buf, component_type))
  }
  @nbt.NBTTag::TagList(component_type, result)
}

///|
fn parse_list_int(buf : ReaderByteBuf) -> FixedArray[Int] raise {
  let size = buf.read_i32()
  FixedArray::makei(size, fn(_) { buf.read_i32() })
}

///|
fn parse_list_long(buf : ReaderByteBuf) -> FixedArray[Int64] raise {
  let size = buf.read_i32()
  FixedArray::makei(size, fn(_) { buf.read_i64() })
}

///|
fn parse_byte_array(buf : ReaderByteBuf) -> @bytes.View raise {
  buf.read_byte_array(buf.read_i32())
}
