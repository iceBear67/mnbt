///|
pub typealias Byte as NBTType

///|
///
pub(all) enum NBTTag {
  TagEnd
  TagByte(Byte)
  TagShort(Int16)
  TagInt(Int)
  TagLong(Int64)
  TagFloat(Float)
  TagDouble(Double)
  TagByteArray(Bytes)
  TagString(String)
  TagList(NBTType, FixedArray[NBTTag])
  TagCompound(String, Map[String, NBTTag])
  TagIntArray(FixedArray[Int])
  TagLongArray(FixedArray[Int64])
} derive(Show, Eq)

///|
pub fn to_type_id(self : NBTTag) -> Byte {
  match self {
    TagIntArray(_) => TypeIntArray
    TagCompound(_) => TypeCompound
    TagList(_) => TypeList
    TagString(_) => TypeString
    TagByteArray(_) => TypeByteArray
    TagDouble(_) => TypeDouble
    TagFloat(_) => TypeFloat
    TagLong(_) => TypeLong
    TagInt(_) => TypeInt
    TagShort(_) => TypeShort
    TagByte(_) => TypeByte
    TagEnd => TypeEnd
    TagLongArray(_) => TypeLongArray
  }
}

///|
pub const TypeEnd : Byte = 0

///|
pub const TypeByte : Byte = 1

///|
pub const TypeShort : Byte = 2

///|
pub const TypeInt : Byte = 3

///|
pub const TypeLong : Byte = 4

///|
pub const TypeFloat : Byte = 5

///|
pub const TypeDouble : Byte = 6

///|
pub const TypeByteArray : Byte = 7

///|
pub const TypeString : Byte = 8

///|
pub const TypeList : Byte = 9

///|
pub const TypeCompound : Byte = 10

///|
pub const TypeIntArray : Byte = 11

///|
pub const TypeLongArray : Byte = 12

///|
pub fn iter(self : NBTTag) -> Iter[NBTTag] {
  return Iter::new(fn(_yield) {
    guard _yield(self) is IterContinue else { IterEnd }
    match self {
      TagCompound(_, comp) => {
        for _, entry in comp.iter() {
          let (_, v) = entry
          for c in v.iter() {
            let r = _yield(c)
            guard r is IterContinue else { return IterEnd }
          }
        }
        return IterResult::IterEnd
      }
      TagList(_type, l) => {
        for i in l {
          for c in i.iter() {
            let r = _yield(c)
            guard r is IterContinue else { return IterEnd }
          }
        }
        return IterResult::IterEnd
      }
      _ => return IterResult::IterEnd
    }
  })
}

///|
pub suberror NoSuchProperty String

///|
pub suberror NotCompoundTag

///|
pub fn node(self : NBTTag, name : String) -> NBTTag raise {
  if self is NBTTag::TagCompound(_, map) && map.contains(name) {
    return map[name]
  } else {
    raise NoSuchProperty(name)
  }
}

///|
pub fn node_at(self : NBTTag, index : Int) -> NBTTag raise {
  if self is NBTTag::TagList(_, l) && l.length() < index {
    return l[index]
  } else {
    raise NoSuchProperty(
      "Index \{index} is too long or the tag is not taglist.",
    )
  }
}

///|
pub fn node_or_create(
  self : NBTTag,
  name : String,
  defaultValue : () -> NBTTag,
) -> NBTTag raise {
  if self is NBTTag::TagCompound(_, map) {
    return map.get_or_init(name, defaultValue)
  } else {
    raise NoSuchProperty(name)
  }
}

///|
pub fn get_int(self : NBTTag, property : String) -> Int raise {
  if self.node(property) is NBTTag::TagInt(i) {
    return i
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn set(self : NBTTag, property : String, value : NBTTag) -> Unit raise {
  if self is TagCompound(_, map) {
    map[property] = value
  } else {
    raise NotCompoundTag
  }
}

///|
pub fn get_short(self : NBTTag, property : String) -> Int16 raise {
  if self.node(property) is NBTTag::TagShort(i) {
    return i
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn get_long(self : NBTTag, property : String) -> Int64 raise {
  if self.node(property) is NBTTag::TagLong(i) {
    return i
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn get_byte(self : NBTTag, property : String) -> Byte raise {
  if self.node(property) is NBTTag::TagByte(i) {
    return i
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn get_string(self : NBTTag, property : String) -> String raise {
  if self is NBTTag::TagCompound(_, map) &&
    map[property] is NBTTag::TagString(i) {
    return i
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn get_compound(
  self : NBTTag,
  property : String,
) -> Map[String, NBTTag] raise {
  if self.node(property) is TagCompound(_, m) {
    return m
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn get_list(self : NBTTag, property : String) -> NBTTag raise {
  if self is NBTTag::TagCompound(_, map) &&
    map[property] is (NBTTag::TagList(_, _) as l) {
    return l
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn get_float(self : NBTTag, property : String) -> Float raise {
  if self.node(property) is NBTTag::TagFloat(i) {
    return i
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn get_double(self : NBTTag, property : String) -> Double raise {
  if self.node(property) is NBTTag::TagDouble(i) {
    return i
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn get_byte_array(self : NBTTag, property : String) -> Bytes raise {
  if self.node(property) is NBTTag::TagByteArray(b) {
    return b
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn as_int(self : NBTTag) -> Int? {
  guard self is TagInt(i) else { return None }
  Some(i)
}

///|
pub fn as_byte(self : NBTTag) -> Byte? {
  guard self is TagByte(i) else { return None }
  Some(i)
}

///|
pub fn as_short(self : NBTTag) -> Int16? {
  guard self is TagShort(i) else { return None }
  Some(i)
}

///|
pub fn as_long(self : NBTTag) -> Int64? {
  guard self is TagLong(i) else { return None }
  Some(i)
}

///|
pub fn as_string(self : NBTTag) -> String? {
  guard self is TagString(i) else { return None }
  Some(i)
}

///|
pub fn as_float(self : NBTTag) -> Float? {
  guard self is TagFloat(i) else { return None }
  Some(i)
}

///|
pub fn as_double(self : NBTTag) -> Double? {
  guard self is TagDouble(i) else { return None }
  Some(i)
}

///|
pub fn as_int_array(self : NBTTag) -> FixedArray[Int]? {
  guard self is TagIntArray(i) else { return None }
  Some(i)
}

///|
pub fn as_long_array(self : NBTTag) -> FixedArray[Int64]? {
  guard self is TagLongArray(i) else { return None }
  Some(i)
}

///|
pub fn as_byte_array(self : NBTTag) -> Bytes? {
  guard self is TagByteArray(i) else { return None }
  Some(i)
}

///|
pub fn as_compound(self : NBTTag) -> (String, Map[String, NBTTag])? {
  guard self is TagCompound(a, b) else { return None }
  Some((a, b))
}

///|
pub fn as_list(self : NBTTag) -> FixedArray[NBTTag]? {
  guard self is TagList(_, b) else { return None }
  Some(b)
}
