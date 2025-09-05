///|
test "test snbt basic literals" {
  inspect(@snbt.parse_token("hello"), content="[Ok(String(\"hello\"))]")
  inspect(@snbt.parse_token("'hello'"), content="[Ok(String(\"hello\"))]")
  inspect(@snbt.parse_token("\"hello\""), content="[Ok(String(\"hello\"))]")
  inspect(@snbt.parse_token("1i"), content="[Ok(Int(1))]")
  inspect(@snbt.parse_token("1s"), content="[Ok(Short(1))]")
  inspect(@snbt.parse_token("1d"), content="[Ok(Double(1))]")
  inspect(@snbt.parse_token("1f"), content="[Ok(Float(1))]")
  inspect(@snbt.parse_token("1l"), content="[Ok(Long(1))]")
  inspect(@snbt.parse_token("1"), content="[Ok(Int(1))]")
  inspect(@snbt.parse_token("true"), content="[Ok(Boolean(true))]")
  inspect(@snbt.parse_token("false"), content="[Ok(Boolean(false))]")
}

///|
test "test array" {
  let result = @snbt.parse_token("[I; 1, 2 ,3]").collect()
  inspect(
    result,
    content="[Ok(ListBegin(Int)), Ok(Int(1)), Ok(Comma), Ok(Int(2)), Ok(Comma), Ok(Int(3)), Ok(ListEnd)]",
  )
  let result = @snbt.parse_token("[L;1b,2s,3i,4l]").collect()
  inspect(
    result,
    content="[Ok(ListBegin(Long)), Ok(Byte(b'\\x01')), Ok(Comma), Ok(Short(2)), Ok(Comma), Ok(Int(3)), Ok(Comma), Ok(Long(4)), Ok(ListEnd)]",
  )
  let result = @snbt.parse_token("[B;1b,2b,3b]")
  inspect(
    result,
    content="[Ok(ListBegin(Byte)), Ok(Byte(b'\\x01')), Ok(Comma), Ok(Byte(b'\\x02')), Ok(Comma), Ok(Byte(b'\\x03')), Ok(ListEnd)]",
  )
  let result = @snbt.parse_token("[3.2,64.5,129.5]")
  inspect(result, content = "[Ok(ListBegin(Unknown)), Ok(Double(3.2)), Ok(Comma), Ok(Double(64.5)), Ok(Comma), Ok(Double(129.5)), Ok(ListEnd)]")
}

///|
test "test compound" {
  let input =
    #|{foo: 1, bar: "abc", baz: {}}
  let result = @snbt.parse_token(input)
  let expect =
    #|[Ok(CompoundBegin), Ok(String("foo")), Ok(SemiColon), Ok(Int(1)), Ok(Comma), Ok(String("bar")), Ok(SemiColon), Ok(String("abc")), Ok(Comma), Ok(String("baz")), Ok(SemiColon), Ok(CompoundBegin), Ok(CompoundEnd), Ok(CompoundEnd)]
  inspect(result, content=expect)

  let input =
    #|{X:3,Y:64,Z:129}
  let result = @snbt.parse_token(input)
  let expect = 
  #|[Ok(CompoundBegin), Ok(String("X")), Ok(SemiColon), Ok(Int(3)), Ok(Comma), Ok(String("Y")), Ok(SemiColon), Ok(Int(64)), Ok(Comma), Ok(String("Z")), Ok(SemiColon), Ok(Int(129)), Ok(CompoundEnd)]
  inspect(result, content = expect)
}

test "test string" {
  let input = #|"Hello \"World!\""
  let result = #|[Ok(String("Hello \"World!\""))]

  inspect(@snbt.parse_token(input), content = result)

  let input = #|'Hello "World!"'
  let result = #|[Ok(String("Hello \"World!\""))]
  inspect(@snbt.parse_token(input), content = result)

  let input = #|'Hello \'World!\''
  let result = #|[Ok(String("Hello 'World!'"))]
  inspect(@snbt.parse_token(input), content = result)

  let input = #|"Hello 'World!'"
  let result = #|[Ok(String("Hello 'World!'"))]
  inspect(@snbt.parse_token(input), content = result)
}
