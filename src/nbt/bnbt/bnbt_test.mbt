///|
test "test reading and writing uncompressed schematic nbt" {
  let schema = @fs.read_file_to_bytes("test_cases/farm.nbt")
  let parsed = @bnbt.parse_uncompressed(schema[:])
  let buffer = @buffer.new()
  @bnbt.write_uncompressed(parsed, buffer)
}

///|
test "check value integrity" {
  let schema = @fs.read_file_to_bytes("test_cases/test_data.nbt")
  let parsed = @bnbt.parse_uncompressed(schema[:])
  assert_true(
    parsed is @nbt.NBTTag::TagCompound(_, _),
    msg="The root element should be a compound.",
  )
  guard parsed is TagCompound(name, value)
  assert_eq(name, "root")
  let key = [
    "byte", "short", "int", "long", "float", "double", "string", "bytearray", "intarray",
    "longarray",
  ]
  for k in key {
    assert_values(value[k])
  }
  try parsed.node("long long ago") catch {
    _ => ()
  } noraise {
    _ => assert_false(true, msg="#member didn't throw for non-exist tags.")
  }
  let givenTag = @nbt.NBTTag::TagString("hello!")
  try parsed.node_or_create("longarray", () => givenTag) catch {
    _ =>
      assert_false(
        true,
        msg="should not throw and create a new member instead...",
      )
  } noraise {
    result =>
      assert_not_eq(
        result,
        givenTag,
        msg="the given default value has override the original one.",
      )
  }
  let created = parsed.node_or_create(
    "see_using_f5_give_me_a_whole_prospective_",
    () => givenTag,
  )
  assert_eq(created, givenTag)
  assert_eq(
    parsed.get_double("double"),
    114514.0,
    msg="property getters are broken",
  )
}

///|
let test_data = "想吃板烧鸡腿堡......"

///|
let test_byte_array : Bytes = (try? @base64.std_decode2bytes(
  "5aSp5L2/44GoISDmgqrprZTjgaghICDlpKnkvb/jgaghIOaCqumtlOOBqCEg5aSp5L2/44GoISDmgqrprZTjgYwhCg==",
)).unwrap()

///|
fn assert_values(tag : @nbt.NBTTag) -> Unit raise {
  match tag {
    TagIntArray(iarr) => assert_eq(iarr, [1, 2, 3, 4, 5])
    TagString(str) => assert_eq(str, test_data)
    TagByteArray(barr) => assert_eq(barr, test_byte_array)
    TagDouble(d) => assert_eq(d, 114514.0)
    TagFloat(f) => assert_eq(f, 42.0)
    TagLong(l) => assert_eq(l, 1)
    TagInt(i) => assert_eq(i, 1)
    TagShort(s) => assert_eq(s, 1)
    TagByte(b) => assert_eq(b, 1)
    TagLongArray(la) => assert_eq(la, [114, 514, 1919, 810])
    _ => assert_false(true, msg="unexpected compound, end or list.")
  }
}
