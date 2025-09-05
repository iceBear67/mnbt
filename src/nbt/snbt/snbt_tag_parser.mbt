
///|
priv struct SNBTTokenReader {
  mut readerIndex : Int
  array : Array[SNBTToken]
}

///|
fn ensure_elements(self : SNBTTokenReader, size? : Int = 1) -> Unit raise {
  if self.readerIndex + (size - 1) >= self.array.length() {
    raise fail("Not enough elements to take \{size}")
  }
}

///|
fn has_next(self : SNBTTokenReader) -> Bool {
  return self.readerIndex < self.array.length()
}

///|
fn next_token(self : SNBTTokenReader) -> SNBTToken raise {
  self.ensure_elements()
  let r = self.array[self.readerIndex]
  self.readerIndex += 1
  r
}

///|
/// This method parses a SNBT into @nbt.NBTTag. By default, a root compound tag whose name is a empty string will
/// also be emitted. This is commonly seen in data generated from notchian software.
/// However, you may need to strip this root tag out when handling NBT generated from third-party softwares
/// like WorldEdit Schematic, whose root tag is named "Schematic" and not empty string.
pub fn parse_tag(input : String) -> @nbt.NBTTag raise {
  let array : Array[SNBTToken] = Array::new()
  for tk in parse_token(input) {
    guard tk is Ok(token) else { raise tk.unwrap_err() }
    array.push(token)
  }
  parse_tag_from_token(array)
}

///|
/// This method tries to strip the root tag if only one elements in the root compound.
/// Also see: #parse_tag
pub fn parse_tag_strip_root(input : String) -> @nbt.NBTTag raise {
  match parse_tag(input) {
    TagCompound(_, map) as c =>
      if map.size() == 1 {
        map.values().peek().unwrap()
      } else {
        c
      }
    other => other
  }
}

///|
/// This method parses a array of SNBTToken to a valid @nbt.NBTTag.
/// Also see: #parse_tag
pub fn parse_tag_from_token(input : Array[SNBTToken]) -> @nbt.NBTTag raise {
  let reader = SNBTTokenReader::{ array: input, readerIndex: 0 }
  return reader._parse_tag_from_token() catch {
    err =>
      raise fail(
        "Failed to parse nbttag: \{err}, nearby tokens: \{reader.array[@cmp.maximum(0, reader.readerIndex - 3):reader.readerIndex]}",
      )
  }
}

///|
fn _parse_tag_from_token(self : SNBTTokenReader) -> @nbt.NBTTag raise {
  if self.has_next() {
    return match self.next_token() {
      ListBegin(_) => {
        self.readerIndex -= 1
        self.parse_list()
      }
      CompoundBegin => {
        self.readerIndex -= 1
        self.parse_compound()
      }
      Double(d) => TagDouble(d)
      Float(f) => TagFloat(f)
      Long(l) => TagLong(l)
      Int(i) => TagInt(i)
      Short(s) => TagShort(s)
      Boolean(b) => TagByte(if b { 1 } else { 0 })
      Byte(b) => TagByte(b)
      String(s) => TagString(s)
      ch => fail("Unexpected token: \{ch}")
    }
  }
  raise fail("End of file")
}

///|
fn parse_compound(self : SNBTTokenReader) -> @nbt.NBTTag raise {
  guard self.has_next() else { raise fail("End of file") }
  let tk = self.next_token()
  guard tk is CompoundBegin else {
    raise fail("Expect a compound begin but got \{tk}")
  }
  let map : Map[String, @nbt.NBTTag] = Map::new()
  let name = if self.readerIndex >= 3 &&
    self.array[self.readerIndex - 3] is String(key) {
    key
  } else {
    ""
  }
  while self.has_next() {
    let tk = self.array[self.readerIndex:]
    match tk {
      [CompoundEnd, ..] => {
        let _ = self.next_token()
        break
      }
      [Comma, ..] => {
        let _ = self.next_token()
        continue
      }
      [String(s), SemiColon, _, ..] => {
        self.readerIndex += 2
        map[s] = self._parse_tag_from_token()
      }
      _ => raise fail("Expect compound end or key and semicolon.]}")
    }
  }
  TagCompound(name, map)
}

///|
fn parse_list(self : SNBTTokenReader) -> @nbt.NBTTag raise {
  let array : Array[@nbt.NBTTag] = Array::new()
  let mut eType : Byte = 0
  for i = 0; self.has_next(); i = i + 1 {
    let element = self.next_token()
    if i == 0 {
      guard element is ListBegin(_t) else {
        raise fail("Expect a listbegin but got \{element}")
      }
      eType = _t.to_type_id().unwrap_or(0)
      continue
    }
    match element {
      ListEnd =>
        return match eType {
          @nbt.TypeInt =>
            @nbt.TagIntArray(
              FixedArray::from_array(array.map(it => it.as_int().unwrap())),
            )
          @nbt.TypeByte =>
            @nbt.TagByteArray(
              Bytes::from_array(array.map(it => it.as_byte().unwrap())),
            )
          @nbt.TypeLong =>
            @nbt.TagLongArray(
              FixedArray::from_array(array.map(it => it.as_long().unwrap())),
            )
          _ => TagList(eType, FixedArray::from_array(array))
        }
      Comma => continue
      _ => // consider an element
        self.readerIndex -= 1
    }
    let ele = self._parse_tag_from_token()
    if i == 1 && eType == 0 {
      eType = ele.to_type_id()
    }
    if ele.to_type_id() != eType {
      array.push(list_element_covariant(eType, ele))
    } else {
      array.push(ele)
    }
  }
  raise fail("Unexpected EOF when parsing list")
}