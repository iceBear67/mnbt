///|
pub enum SNBTToken {
  CompoundBegin
  CompoundEnd
  SemiColon
  Comma
  String(String)
  Byte(Byte)
  Boolean(Bool)
  Short(Int16)
  Int(Int)
  Long(Int64)
  Float(Float)
  Double(Double)
  ListBegin(SNBTListType)
  ListEnd
} derive(Show, Eq)

///|
pub enum SNBTListType {
  Byte
  Int
  Long
  Unknown
} derive(Show, Eq)

///|
pub fn to_type_id(self : SNBTListType) -> @nbt.NBTType? {
  Some(
    match self {
      Long => @nbt.TypeLong
      Int => @nbt.TypeInt
      Byte => @nbt.TypeByte
      Unknown => return None
    },
  )
}

///|
pub suberror InvalidToken String

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

///|
pub fn parse_token(input : String) -> Iter[Result[SNBTToken, Error]] {
  return newCharBuffer(input[:])._parse_token()
}

///|
fn _parse_token(
  self : CharBuffer,
  prefer_string? : Bool = false,
) -> Iter[Result[SNBTToken, Error]] {
  return Iter::new(c => while self.has_remaining() {
    self.skip_next_whitespace()
    let result = match self.peek().unwrap() {
      '{' | '}' | ':' | ']' | ',' =>
        match self.next_char().unwrap() { // move reader index
          '{' => c(Ok(SNBTToken::CompoundBegin))
          '}' => c(Ok(SNBTToken::CompoundEnd))
          ':' => c(Ok(SNBTToken::SemiColon))
          ']' => c(Ok(SNBTToken::ListEnd))
          ',' => c(Ok(SNBTToken::Comma))
          _ => panic()
        }
      '[' => self.parse_token_list().run(c)
      '\"' | '\'' =>
        (try? self.parse_string_token()).map(c => SNBTToken::String(c)) |> c
      _ => {
        let r = try? self.parse_string_token()
        if prefer_string {
          c(r.map(r => infer_string_type_or_string(r)))
        } else {
          c(r.map(r => infer_string_type_or_int(r)))
        }
      }
    }
    if result == IterEnd {
      return result
    }
  } else {
    IterResult::IterEnd
  })
}

///|
fn infer_string_type_or_int(string : String) -> SNBTToken {
  match infer_string_type(string) {
    None =>
      (try? @strconv.parse_int(string[:]))
      .map(SNBTToken::Int(_))
      .or_else(() => (try? @strconv.parse_double(string[:]))
        .map(SNBTToken::Double(_))
        .or_else(() => SNBTToken::String(string)))
    Some(s) => s
  }
}

///|
///      raise fail("Incompatible type ")
fn infer_string_type_or_string(string : String) -> SNBTToken {
  match infer_string_type(string) {
    None => SNBTToken::String(string)
    Some(s) => s
  }
}

///|
/// This method infers the type of a given string.
/// For strings that do not end with a special suffix, return none.
fn infer_string_type(string : String) -> SNBTToken? {
  guard !string.is_empty() else { Some(SNBTToken::String("")) }
  match string { // boolean
    "true" => return Some(SNBTToken::Boolean(true))
    "false" => return Some(SNBTToken::Boolean(false))
    _ => ()
  }
  let lastIndex = string.char_length() - 1
  let tail = string.get_char(lastIndex).unwrap()
  let content = match (try? string[0:lastIndex]) {
    Err(_) => return None
    Ok(z) => z
  }
  match tail { // numeric types
    'b' | 'B' =>
      if (try? @strconv.parse_int(content)).map(it => it.reinterpret_as_uint())
        is Ok(r) &&
        r >= @byte.min_value.to_uint() &&
        r <= @byte.max_value.to_uint() {
        return Some(SNBTToken::Byte(r.to_byte()))
      } else {
        None
      }
    's' | 'S' =>
      if (try? @strconv.parse_int(content)) is Ok(r) &&
        r >= @int16.min_value.to_int() &&
        r <= @int16.max_value.to_int() {
        return Some(SNBTToken::Short(r.to_int16()))
      } else {
        None
      }
    'l' | 'L' =>
      (try? @strconv.parse_int64(content)).map(SNBTToken::Long(_)).to_option()
    'f' | 'F' =>
      if (try? @strconv.parse_double(content)) is Ok(r) &&
        r >= @float.min_value.to_double() &&
        r <= @float.max_value.to_double() {
        Some(SNBTToken::Float(r.to_float()))
      } else {
        None
      }
    'd' | 'D' =>
      (try? @strconv.parse_double(content))
      .map(SNBTToken::Double(_))
      .to_option()
    'i' | 'I' =>
      (try? @strconv.parse_int(content)).map(SNBTToken::Int(_)).to_option()
    _ => None
  }
}

///|
/// In SNBT, there are 3 kinds of string:
/// - unquoted: quotes are omitted when the string matches regex "[a-zA-Z0-9_\-\.\+]"
/// - double-quote'd: string that is wrapped in ""
/// - single-quote'd: string that is wrapped in ''
/// Quoted strings follow the [escape rule](https://minecraft.wiki/w/NBT_format#Escape_sequences) with some exceptions according to its kind.
/// This method assumpts that the buffer has remaining elements, and the next char is the begin of [quoted]string.
fn parse_string_token(self : CharBuffer) -> String raise {
  let escape = self.peek().unwrap()
  guard escape == '\'' || escape == '"' else {
    return self.parse_string_unquoted().to_string()
  }
  let _ = self.next_char() // move reader index
  self.mark()
  let stringBuffer = StringBuilder::new()
  while self.has_remaining() {
    let current = self.next_char().unwrap()
    if current == '\\' {
      stringBuffer.write_char(self.read_escape_character())
      continue
    }
    if current == escape {
      break
    }
    stringBuffer.write_char(current)
  }
  stringBuffer.to_string()
}

///|
/// - unquoted: quotes are omitted when the string matches regex "[a-zA-Z0-9_\-\.\+]"
/// This method assumpts that the buffer is at the begin of the unquoted string.
fn parse_string_unquoted(self : CharBuffer) -> @string.View raise {
  self.mark()
  while self.has_remaining() {
    match self.next_char().unwrap() {
      'a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '-' | '.' | '+' => continue
      _ => { // here we consider space as a indicator of end
        guard self.move_backward() else {
          raise fail(
            "Unexpected begin of document when parsing unquoted string",
          )
        }
        break
      }
    }
  }
  self.view[self.mark:self.readerIndex]
}

///|
/// This method assumpts that the buffer position is after the escape char(\), i.e begin of the escape sequence.
/// Allowed escape sequences: \n \s \\ \' \" \xhh \uhhhh \Uhhhhhhhh
fn read_escape_character(self : CharBuffer) -> Char raise {
  let begin = self.readerIndex
  guard self.has_remaining() else {
    raise fail("Unexpected escape at end of file")
  }
  let hex = match self.next_char().unwrap() {
    'n' => 0x0a
    's' => 0x20
    '\\' => 0x5C // \
    '\'' => 0x27
    '\"' => 0x22
    'x' => {
      guard self.length() >= 2 else { raise fail("Unexpected EOF") }
      @strconv.parse_int(self.next_string(2), base=16)
    }
    'u' => {
      guard self.length() >= 4 else { raise fail("Unexpected EOF") }
      @strconv.parse_int(self.next_string(4), base=16)
    }
    'U' => {
      guard self.length() >= 8 else { raise fail("Unexpected EOF") }
      @strconv.parse_int(self.next_string(8), base=16)
    }
    z => raise InvalidToken("Unexpected escape sequence \{z}")
  }
  guard Int::to_char(hex) is Some(char) else {
    raise fail("Invalid escape char at \{begin}")
  }
  char
}

///|
/// This method assumpts that the buffer position is at the begin of list, i.e "[".
/// Since integers can be indistinguistable from unquoted strings, this parser
/// sets prefer_string to false when a IntArray appears, and sets it back to false when the list ends.
fn parse_token_list(self : CharBuffer) -> Iter[Result[SNBTToken, Error]] {
  Iter::new(c => {
    let head = self.next_char()
    guard head is Some('[') else {
      return c(
        Err(
          InvalidToken(
            "Expect '[' but got \{head} instead at offset \{self.readerIndex}",
          ),
        ),
      )
    }
    let _type = match self.peek() {
      Some('B') => SNBTListType::Byte
      Some('I') => SNBTListType::Int
      Some('L') => SNBTListType::Long
      None => return c(Err(EndOfString("Unexpected EOF at list begin")))
      _ => {
        guard c(Ok(SNBTToken::ListBegin(SNBTListType::Unknown))) is IterContinue else {
          return IterEnd
        }
        return self._parse_token().run(c)
      }
    }
    let _ = self.next_char() // the type of primitive array
    let r = self.next_char()
    guard r is Some(';') else {
      // nofmt
      return c(
        Err(
          InvalidToken(
            "Expect char ';' but got \{r} at index \{self.readerIndex}",
          ),
        ),
      )
    }
    guard c(Ok(SNBTToken::ListBegin(_type))) is IterContinue else {
      return IterEnd
    }
    for token in self._parse_token(prefer_string=_type != SNBTListType::Int) {
      guard c(token) is IterContinue else { return IterEnd }
      if token is Ok(m) && m is SNBTToken::ListEnd {
        break
      }
    }
    self._parse_token().run(c)
  })
}

///|
fn list_element_covariant(
  earlyType : @nbt.NBTType,
  value : @nbt.NBTTag,
) -> @nbt.NBTTag raise {
  match earlyType {
    @nbt.TypeByte => ()
    @nbt.TypeShort =>
      match value {
        @nbt.NBTTag::TagByte(b) => return TagShort(b.to_int16())
        _ => ()
      }
    @nbt.TypeInt =>
      match value {
        @nbt.NBTTag::TagByte(b) => return TagInt(b.to_int())
        @nbt.NBTTag::TagShort(s) => return TagInt(s.to_int())
        // float32 conversion may lead to information loss
        _ => ()
      }
    @nbt.TypeLong =>
      match value {
        @nbt.NBTTag::TagByte(b) => return TagLong(b.to_int64())
        @nbt.NBTTag::TagShort(s) => return TagLong(s.to_int64())
        @nbt.NBTTag::TagInt(int) => return TagLong(int.to_int64())
        _ => ()
      }
    @nbt.TypeFloat =>
      match value {
        @nbt.NBTTag::TagByte(b) => return TagFloat(b.to_float())
        @nbt.NBTTag::TagShort(s) => return TagFloat(s.to_int().to_float())
        @nbt.NBTTag::TagInt(int) => return TagFloat(int.to_float())
        _ => ()
      }
    @nbt.TypeDouble =>
      match value {
        @nbt.NBTTag::TagByte(b) => return TagDouble(b.to_double())
        @nbt.NBTTag::TagShort(s) => return TagDouble(s.to_int().to_double())
        @nbt.NBTTag::TagInt(int) => return TagDouble(int.to_double())
        @nbt.NBTTag::TagLong(l) => return TagDouble(l.to_double())
        _ => ()
      }
    _ => ()
  }
  raise fail("Cannot convert \{value} into tag with type id \{earlyType}")
}
