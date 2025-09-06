# iceBear67/mnbt

A simple parser for [Named-Binary-Tag (NBT) Data Format](https://minecraft.wiki/w/NBT_format), which is commonly used in Minecraft.

This library supports both SNBT and NBT.

# Usage

NBT consists of some kind of tags, which are represented in MoonBit enum `@nbt.NBTTag`. You can access the tree via pattern matching or accessor methods.

Here's an example:

```MoonBit
fn match_tag(tag: @nbt.NBTTag) -> UNit {
    match tag {
        NBTTag::TagString(str) => println(str)
        NBTTag::TagInt(i) => println(i)
        _ => ...
    }
}

fn access_tag(tag: @nbt.NBTTag) -> String? {
    try tag.node("Schematic").node("BlockEntities").node_at(0).get_string("Id") catch {
        NoSuchProperty(msg) => return Err(msg)
    } noraise {
        v => return Ok(v)
    }
}
```

For GZipped NBT Tags, you may experience stack overflow on WASM Targets. This is an issue from upstream [gmlewis/moonbit-gzip](https://github.com/gmlewis/moonbit-gzip/releases/tag/v0.25.0), you can mitigate the problem by decompressing the given input beforehand.

Region formats like "Linear" can also be processed by pre decompression then use `parse_uncompressed` to get a NBTTag.

Here's an example taken from our tests:
```MoonBit
test "test reading and writing uncompressed schematic nbt" {
  let schema = @fs.read_file_to_bytes("test_cases/farm.nbt")
  let parsed = @bnbt.parse_auto(schema[:])
  let buffer = @buffer.new()
  @bnbt.write_uncompressed(parsed, buffer)
}
```

I haven't tested its speed yet but it should be fast enough for most uses.

## SNBT

Since mnbt 0.3.0, SNBT (String representation of NBT) is also supported.

Check our unit tests for more examples! Before using these functions, please check the documentation carefully.

```moonbit
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
test "test writer" {
  let input =
    #|{X:3,Y:64,Z:129}
  let result = @snbt.parse_tag(input)
  let expect =
    #|{"X": 3,"Y": 64,"Z": 129}
  inspect(@snbt.write(result).join(""), content=expect)
}
```

SNBT Parser also supports stream parsing.
```moonbit
// Iter[Result[SNBTToken, Error]].
// You're expected to raise the error but you can keep reading too.
@snbt.parse_token("hello").all(it => it is @snbt.SNBTToken)
```

Unfortunately, parsing SNBT into NBTTags in stream mode isn't supported, which means you will need to
collect all these tokens before parsing tags. 

Contributions are always welcome!


# Known limitation

- Escape sequence `\N{Snowman}` won't work.