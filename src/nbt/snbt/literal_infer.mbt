
///|
fn infer_string_type_or_int(string : String) -> SNBTToken {
  match infer_string_type(string) {
    None =>
      (try? @strconv.parse_int(string[:]))
      .map(SNBTToken::Int(_))
      .or_else(() => (try? @strconv.parse_double(string[:]))
        .map(floatLike => if floatLike <= @float.max_value.to_double() &&
          floatLike >= @float.min_value.to_double() {
          Float(floatLike.to_float())
        } else {
          Double(floatLike)
        })
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
  let mut lastIndex = string.char_length() - 1
  let tail = string.get_char(lastIndex).unwrap()
  let signed = if string.length() > 2 {
    match string.get_char(lastIndex - 1) {
      Some('U') | Some('u') => {
        lastIndex -= 1
        false
      }
      Some('s') | Some('S') => {
        lastIndex -=1 
        true
      }
      _ => true
    }
  } else {
    true
  }
  let content = match (try? string[0:lastIndex]) {
    Err(_) => return None
    Ok(z) => z
  }
  if signed {
    infer_signed(content, tail)
  } else {
    infer_unsigned(content, tail)
  }
}

///|
fn infer_unsigned(content : @string.View, tail : Char) -> SNBTToken? {
  match tail { // numeric types
    'b' | 'B' =>
      if (try? @strconv.parse_uint(content)) is Ok(r) {
        return Some(SNBTToken::Byte(r.to_byte()))
      } else {
        None
      }
    's' | 'S' =>
      if (try? @strconv.parse_uint(content)) is Ok(r){
        return Some(SNBTToken::Short(r.reinterpret_as_int().to_int16()))
      } else {
        None
      }
    'l' | 'L' =>
      (try? @strconv.parse_uint64(content))
      .map(it => it.reinterpret_as_int64())
      .map(SNBTToken::Long(_))
      .to_option()
    'f' | 'F' | 'd' | 'D' => infer_signed(content, tail)
    'i' | 'I' =>
      (try? @strconv.parse_uint(content))
      .map(it => it.reinterpret_as_int())
      .map(SNBTToken::Int(_))
      .to_option()
    _ => None
  }
}

///|
fn infer_signed(content : @string.View, tail : Char) -> SNBTToken? {
  match tail { // numeric types
    'b' | 'B' =>
      if (try? @strconv.parse_int(content))
        is Ok(r) {
        return Some(SNBTToken::Byte((r & 0xFF).to_byte()))
      } else {
        None
      }
    's' | 'S' =>
      if (try? @strconv.parse_int(content)) is Ok(r) {
        return Some(SNBTToken::Short(r.to_int16()))
      } else {
        None
      }
    'l' | 'L' =>
      (try? @strconv.parse_int64(content)).map(SNBTToken::Long(_)).to_option()
    'f' | 'F' =>
      if (try? @strconv.parse_double(content)) is Ok(r) {
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
