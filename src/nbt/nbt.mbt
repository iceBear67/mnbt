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
  TagByteArray(@bytes.View)
  TagString(String)
  TagList(NBTType, FixedArray[NBTTag])
  TagCompound(String, Map[String, NBTTag])
  TagIntArray(FixedArray[Int])
  TagLongArray(FixedArray[Int64])
} derive(Show, Eq)

///|
pub fn NBTTag::to_type_id(self : NBTTag) -> Byte {
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
pub fn NBTTag::iter(self : NBTTag) -> Iter[NBTTag] {
  return Iter::new(fn(_yield) {
    guard _yield(self) is IterContinue else { IterEnd }
    match self {
      TagCompound(name, comp) => {
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
pub suberror NotCompoundTag

///|
pub fn NBTTag::node(self : NBTTag, name : String) -> NBTTag raise {
  if self is NBTTag::TagCompound(_, map) && map.contains(name) {
    return map[name]
  } else {
    raise NoSuchProperty(name)
  }
}

pub fn NBTTag::node_at(self:NBTTag, index: Int) -> NBTTag raise {
  if self is NBTTag::TagList(t, l) && l.length() < index {
    return l[index]
  } else {
    raise NoSuchProperty("Index \{index} is too long or the tag is not taglist.")
  }
}

pub fn NBTTag::node_or_create(self:NBTTag, name: String, defaultValue: () -> NBTTag) -> NBTTag raise {
  if self is NBTTag::TagCompound(_, map) {
    return map.get_or_init(name, defaultValue)
  } else {
    raise NoSuchProperty(name)
  }
}

///|
pub fn NBTTag::get_int(self : NBTTag, property : String) -> Int raise {
  if self.node(property) is NBTTag::TagInt(i) {
    return i
  } else {
    raise NoSuchProperty(property)
  }
}

pub fn NBTTag::set(self: NBTTag, property: String, value: NBTTag) -> Unit raise {
  if self is TagCompound(_, map) {
    map[property] = value
  } else {
    raise NotCompoundTag
  }
}


///|
pub fn NBTTag::get_short(self : NBTTag, property : String) -> Int16 raise {
  if self.node(property) is NBTTag::TagShort(i) {
    return i
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn NBTTag::get_long(self : NBTTag, property : String) -> Int64 raise {
  if self.node(property) is NBTTag::TagLong(i) {
    return i
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn NBTTag::get_byte(self : NBTTag, property : String) -> Byte raise {
  if self.node(property) is NBTTag::TagByte(i) {
    return i
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn NBTTag::get_string(self : NBTTag, property : String) -> String raise {
  if self is NBTTag::TagCompound(_, map) &&
    map[property] is NBTTag::TagString(i) {
    return i
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn NBTTag::get_compound(
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
pub fn NBTTag::get_list(self : NBTTag, property : String) -> NBTTag raise {
  if self is NBTTag::TagCompound(_, map) &&
    map[property] is (NBTTag::TagList(_, _) as l) {
    return l
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn NBTTag::get_float(self : NBTTag, property : String) -> Float raise {
  if self.node(property) is NBTTag::TagFloat(i) {
    return i
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn NBTTag::get_double(self : NBTTag, property : String) -> Double raise {
  if self.node(property) is NBTTag::TagDouble(i) {
    return i
  } else {
    raise NoSuchProperty(property)
  }
}

///|
pub fn NBTTag::get_byte_array(
  self : NBTTag,
  property : String,
) -> @bytes.View raise {
  if self.node(property)is NBTTag::TagByteArray(b) {
    return b
  } else {
    raise NoSuchProperty(property)
  }
}
