///|
test "test reading and writing uncompressed schematic nbt" {
  let schema = @fs.read_file_to_bytes("test_cases/farm.nbt")
  let parsed = @bnbt.parse_uncompressed(schema[:])
  let buffer = @buffer.new()
  @bnbt.write_uncompressed(parsed, buffer)
  let _ = @bnbt.parse_uncompressed(buffer.contents()[:])

}

///|
test "check value integrity, uncompressed" {
  let schema = @fs.read_file_to_bytes("test_cases/test_data.nbt")
  let parsed = @bnbt.parse_uncompressed(schema[:])
  validate_uncompressed(parsed)
}

///|
test "check value integrity, zlib-defalted" {
  let schema = @fs.read_file_to_bytes("test_cases/test_data.nbt.zlib")
  let parsed = @bnbt.parse_zlib(schema)
  validate_uncompressed(parsed)
}

///|
test "check value integrity, gzipped" {
  let schema = @fs.read_file_to_bytes("test_cases/test_data.dat")
  let parsed = @bnbt.parse_gzip(schema)
  validate_uncompressed(parsed)
}

///|
test "check value integrity, using auto recognition" {
  let zlib = @fs.read_file_to_bytes("test_cases/test_data.nbt.zlib")
  let gzip = @fs.read_file_to_bytes("test_cases/test_data.dat")
  let uncompressed = @fs.read_file_to_bytes("test_cases/test_data.nbt")
  validate_uncompressed(@bnbt.parse_auto(gzip))
  validate_uncompressed(@bnbt.parse_auto(zlib))
  validate_uncompressed(@bnbt.parse_auto(uncompressed))
}

///|
test "test iter" {
  let uncompressed = @bnbt.parse_uncompressed(
    @fs.read_file_to_bytes("test_cases/test_data.nbt"),
  )
  let expect =
    #|[TagCompound("root", {"byte": TagByte(b'\x01'), "short": TagShort(1), "int": TagInt(1), "long": TagLong(1), "float": TagFloat(42), "double": TagDouble(114514), "string": TagString("想吃板烧鸡腿堡......"), "bytearray": TagByteArray(b"\xe5\xa4\xa9\xe4\xbd\xbf\xe3\x81\xa8\x21\x20\xe6\x82\xaa\xe9\xad\x94\xe3\x81\xa8\x21\x20\x20\xe5\xa4\xa9\xe4\xbd\xbf\xe3\x81\xa8\x21\x20\xe6\x82\xaa\xe9\xad\x94\xe3\x81\xa8\x21\x20\xe5\xa4\xa9\xe4\xbd\xbf\xe3\x81\xa8\x21\x20\xe6\x82\xaa\xe9\xad\x94\xe3\x81\x8c\x21\x0a"), "intarray": TagIntArray([1, 2, 3, 4, 5]), "longarray": TagLongArray([114, 514, 1919, 810])}), TagByte(b'\x01'), TagShort(1), TagInt(1), TagLong(1), TagFloat(42), TagDouble(114514), TagString("想吃板烧鸡腿堡......"), TagByteArray(b"\xe5\xa4\xa9\xe4\xbd\xbf\xe3\x81\xa8\x21\x20\xe6\x82\xaa\xe9\xad\x94\xe3\x81\xa8\x21\x20\x20\xe5\xa4\xa9\xe4\xbd\xbf\xe3\x81\xa8\x21\x20\xe6\x82\xaa\xe9\xad\x94\xe3\x81\xa8\x21\x20\xe5\xa4\xa9\xe4\xbd\xbf\xe3\x81\xa8\x21\x20\xe6\x82\xaa\xe9\xad\x94\xe3\x81\x8c\x21\x0a"), TagIntArray([1, 2, 3, 4, 5]), TagLongArray([114, 514, 1919, 810])]
  inspect(uncompressed.iter().collect(), content=expect)
}

///|
test "test plain writer" {
  let schema = @fs.read_file_to_bytes("test_cases/test_data.nbt")
  let parsed = @bnbt.parse_uncompressed(schema[:])
  let buf = @buffer.new()
  let _ = @bnbt.write_uncompressed(parsed, buf)
  validate_uncompressed(parsed)
  @fs.write_bytes_to_file("/tmp/test.nbt", buf.contents())
  validate_uncompressed(@bnbt.parse_uncompressed(buf.contents()))
}

///|
test "test gzip writer" {
  let schema = @fs.read_file_to_bytes("test_cases/test_data.nbt")
  let parsed = @bnbt.parse_uncompressed(schema[:])
  let gzippedd = @bnbt.write_gzip(parsed).to_bytes()
  validate_uncompressed(@bnbt.parse_gzip(gzippedd))
}

///|
test "test zlib writer" {
  let schema = @fs.read_file_to_bytes("test_cases/test_data.nbt")
  let parsed = @bnbt.parse_uncompressed(schema[:])
  let zlib = @bnbt.write_zlib(parsed)
  validate_uncompressed(@bnbt.parse_zlib(zlib.to_bytes()))
}

///|
fn validate_uncompressed(parsed : @nbt.NBTTag) -> Unit raise {
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
