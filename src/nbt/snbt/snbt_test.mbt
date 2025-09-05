///|
test "test parsing primitive tags" {
  inspect(@snbt.parse_tag("hello"), content="TagString(\"hello\")")
  inspect(@snbt.parse_tag("'hello'"), content="TagString(\"hello\")")
  inspect(@snbt.parse_tag("\"hello\""), content="TagString(\"hello\")")
  inspect(@snbt.parse_tag("1i"), content="TagInt(1)")
  inspect(@snbt.parse_tag("1s"), content="TagShort(1)")
  inspect(@snbt.parse_tag("1d"), content="TagDouble(1)")
  inspect(@snbt.parse_tag("1f"), content="TagFloat(1)")
  inspect(@snbt.parse_tag("1l"), content="TagLong(1)")
  inspect(@snbt.parse_tag("1"), content="TagInt(1)")
  inspect(@snbt.parse_tag("true"), content="TagByte(b'\\x01')")
  inspect(@snbt.parse_tag("false"), content="TagByte(b'\\x00')")
  inspect(@snbt.parse_tag("[1,2,3,4]"), content="TagIntArray([1, 2, 3, 4])")
  inspect(
    @snbt.parse_tag("[1b,2b,3b,4b]"),
    content="TagByteArray(b\"\\x01\\x02\\x03\\x04\")",
  )
  inspect(@snbt.parse_tag("[1i,2s,3b,4b]"), content="TagIntArray([1, 2, 3, 4])")
  inspect(
    @snbt.parse_tag("[I;1i,2i,3i,4i]"),
    content="TagIntArray([1, 2, 3, 4])",
  )
  inspect(
    @snbt.parse_tag("[L;1i,2i,3i,4i]"),
    content="TagLongArray([1, 2, 3, 4])",
  )
  inspect(
    @snbt.parse_tag("[B;true, 1b, 2b]"),
    content="TagByteArray(b\"\\x01\\x01\\x02\")",
  )
  inspect(@snbt.parse_tag("1."), content="TagFloat(1)")
  //-16b, -16sb, and 240uB all represent byte value -16.
  //15s, 15sS, and 15Us all represent short value 15.
  //82u, -87uI, 30bu, and 253sb are all incorrect and give errors.

  inspect(@snbt.parse_tag("-16b"), content="TagByte(b'\\xF0')")
  inspect(@snbt.parse_tag("-16sb"), content="TagByte(b'\\xF0')")
  inspect(@snbt.parse_tag("240Ub"), content="TagByte(b'\\xF0')")
  inspect(@snbt.parse_tag("15s"), content="TagShort(15)")
  inspect(@snbt.parse_tag("15sS"), content="TagShort(15)")
  inspect(@snbt.parse_tag("15Us"), content="TagShort(15)")

  inspect(@snbt.parse_tag("15UL"), content="TagLong(15)")
  inspect(@snbt.parse_tag("15L"), content="TagLong(15)")

  inspect(@snbt.parse_tag("-1"), content="TagInt(-1)")
  inspect(@snbt.parse_tag("4294967295ui"), content="TagInt(-1)")
}

///|
test "test compound" {
  let input =
    #|{foo: 1, bar: "abc", baz: {}}
  let result = @snbt.parse_tag(input)
  let expect =
    #|TagCompound("", {"foo": TagInt(1), "bar": TagString("abc"), "baz": TagCompound("baz", {})})
  inspect(result, content=expect)
  let input =
    #|{X:3,Y:64,Z:129}
  let result = @snbt.parse_tag(input)
  let expect =
    #|TagCompound("", {"X": TagInt(3), "Y": TagInt(64), "Z": TagInt(129)})
  inspect(result, content=expect)
}

///|
test "test reader" {
  let schema = @fs.read_file_to_bytes("test_cases/test_data.nbt")
  let parsed = @bnbt.parse_uncompressed(schema[:])
  let result =
    #|{"root" :{"byte": 1B,"short": 1s,"int": 1,"long": 1L,"float": 42f,"double": 114514d,"string": "想吃板烧鸡腿堡......","bytearray": [B;229B,164B,169B,228B,189B,191B,227B,129B,168B,33B,32B,230B,130B,170B,233B,173B,148B,227B,129B,168B,33B,32B,32B,229B,164B,169B,228B,189B,191B,227B,129B,168B,33B,32B,230B,130B,170B,233B,173B,148B,227B,129B,168B,33B,32B,229B,164B,169B,228B,189B,191B,227B,129B,168B,33B,32B,230B,130B,170B,233B,173B,148B,227B,129B,140B,33B,10B],"intarray": [I;1,2,3,4,5],"longarray": [L;114L,514L,1919L,810L]}}
  inspect(@snbt.write(parsed).join(""), content=result)
}

///|
test "test writer" {
  let input =
    #|{X:3,Y:64,Z:129}
  let result = @snbt.parse_tag(input)
  let expect =
    #|{"X": 3,"Y": 64,"Z": 129}
  inspect(@snbt.write_without_root(result).join(""), content=expect)
}

///|
test "test writer with schematic, depending on bnbt test" {
  let schema = @fs.read_file_to_bytes("test_cases/farm.nbt")
  let parsed = @bnbt.parse_uncompressed(schema[:])
  let snbt_out = @snbt.write(parsed).join("")
  let parsed_snbt = @snbt.parse_tag_strip_root(snbt_out)
  assert_eq(parsed_snbt, parsed)
}
