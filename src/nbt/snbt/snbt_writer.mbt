///|
/// This method transforms a NBTTag into a Iter[String], wite the following features:
/// 1. Strings are always quoted within a double-quote, to prevent vague semantics.
/// 2. Number values are always followed by a suffix indicating their actual type. This also applied to key of compound.
/// 3. The root tag won't be omitted.
/// 
/// By joining the Iter you got the complete string of the snbt output.
pub fn write(nbt : @nbt.NBTTag) -> Iter[String] {
  Iter::new(c => match nbt {
    TagCompound(name, _) =>
      if c("{\"\{escape_snbt_dquote(name)}\" :") == IterEnd ||
        write_without_root(nbt).run(c) == IterEnd {
        IterEnd
      } else {
        c("}")
      }
    other => write_without_root(other).run(c)
  })
}

///|
fn write_without_root(nbt : @nbt.NBTTag) -> Iter[String] {
  Iter::new(c => {
    let r = match nbt {
      TagCompound(_, compound) => {
        guard c("{") == IterContinue else { return IterEnd }
        let mut i = 0
        for k, v in compound {
          if c("\"\{escape_snbt_dquote(k)}\": ") == IterEnd ||
            write_without_root(v).run(c) == IterEnd {
            return IterEnd
          }
          i += 1
          if i != compound.size() && c(",") == IterEnd {
            return IterEnd
          }
        }
        return c("}")
      }
      TagList(_, l) => write_array(l, "[").run(c)
      TagByteArray(barr) => write_array(barr.to_fixedarray(), "[B;").run(c)
      TagIntArray(iarr) => write_array(iarr, "[I;").run(c)
      TagLongArray(larr) => write_array(larr, "[L;").run(c)
      TagString(s) => ToNBTString::string(s, c)
      TagDouble(d) => ToNBTString::string(d, c)
      TagFloat(f) => ToNBTString::string(f, c)
      TagLong(l) => ToNBTString::string(l, c)
      TagInt(i) => ToNBTString::string(i, c)
      TagShort(s) => ToNBTString::string(s, c)
      TagByte(b) => ToNBTString::string(b, c)
      TagEnd => return IterEnd
    }
    r
  })
}

///|
priv trait ToNBTString {
  string(self : Self, consumer : (String) -> IterResult) -> IterResult
}

///|
fn[T : ToNBTString] write_array(
  arr : FixedArray[T],
  prefix : String,
) -> Iter[String] {
  return Iter::new(c => {
    if c(prefix) == IterEnd {
      return IterEnd
    }
    for i, b in arr {
      if b.string(c) == IterEnd {
        return IterEnd
      }
      if i != arr.length() - 1 && c(",") == IterEnd {
        return IterEnd
      }
    }
    c("]")
  })
}

///|
impl ToNBTString for String with string(
  self : String,
  consumer : (String) -> IterResult,
) {
  consumer("\"\{escape_snbt_dquote(self)}\"")
}

///|
impl ToNBTString for @nbt.NBTTag with string(
  self : @nbt.NBTTag,
  consumer : (String) -> IterResult,
) {
  write_without_root(self).run(consumer)
}

///|
impl ToNBTString for Byte with string(
  self : Byte,
  consumer : (String) -> IterResult,
) {
  consumer(self.to_int().to_string() + "B")
}

///|
impl ToNBTString for Int with string(
  self : Int,
  consumer : (String) -> IterResult,
) {
  consumer(self.to_string())
}

///|
impl ToNBTString for Int64 with string(
  self : Int64,
  consumer : (String) -> IterResult,
) {
  consumer(self.to_string() + "L")
}

///|
impl ToNBTString for Int16 with string(
  self : Int16,
  consumer : (String) -> IterResult,
) {
  consumer(self.to_string() + "s")
}

///|
impl ToNBTString for Float with string(
  self : Float,
  consumer : (String) -> IterResult,
) {
  consumer(self.to_string() + "f")
}

///|
impl ToNBTString for Double with string(
  self : Double,
  consumer : (String) -> IterResult,
) {
  consumer(self.to_string() + "d")
}

///|
pub fn escape_snbt_dquote(str : String) -> String {
  str.replace_all(old="\n", new="\\n").replace_all(old="\\", new="\\\\")
}
