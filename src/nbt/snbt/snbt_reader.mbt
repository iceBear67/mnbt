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
      '[' => {
        self.parse_token_list().run(c)
      }
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
      ',' | '}' | ']' | ':' | ' ' => { // here we consider space as a indicator of end
        guard self.move_backward() else {
          raise fail(
            "Unexpected begin of document when parsing unquoted string",
          )
        }
        break
      }
      ch => raise fail("Unexpected character: \{ch}")
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
