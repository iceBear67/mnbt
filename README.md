# iceBear67/mnbt

A simple parser for binary variant of [Named-Binary-Tag (NBT) Data Format](https://minecraft.wiki/w/NBT_format), which is commonly used in Minecraft.

# Usage

NBT consist of some kind of tags, which are represented in MoonBit enum `@nbt.NBTTag`. You can access the tree via pattern matching or accessor methods.

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

Usually, NBT files are compressed in GZip format, which unfortunately haven't been supported in MoonBit community. However, uncompressed or zlib compressed NBT files are supported by this library, and you can process GZipped NBT files by pre-decompressing it beforehand.

Region formats like "Linear" can also be processed by decompressing then using `parse_uncompressed` to get a NBTTag.

Here's an example taken from our tests:
```MoonBit
test "test reading and writing uncompressed schematic nbt" {
  let schema = @fs.read_file_to_bytes("test_cases/farm.nbt")
  let parsed = @bnbt.parse_uncompressed(schema[:])
  let buffer = @buffer.new()
  @bnbt.write_uncompressed(parsed, buffer)
}
```

I haven't tested its speed yet but it should be fast enough for most uses.