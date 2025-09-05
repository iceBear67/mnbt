///|
pub struct CharBuffer {
  mut readerIndex : Int
  mut mark : Int
  view : @string.View
}

///|
pub suberror EndOfString String

///|
fn newCharBuffer(str : @string.View) -> CharBuffer {
  CharBuffer::{ readerIndex: 0, mark: 0, view: str }
}

///|
fn slice(self : CharBuffer, begin : Int, end : Int) -> CharBuffer raise {
  let view = self.view[self.readerIndex + begin:self.readerIndex + end]
  { readerIndex: 0, mark: 0, view }
}

///|
fn ensureCapacity(self : CharBuffer, capacity : Int) -> Bool {
  self.view.length() - self.readerIndex - capacity >= 0
}

///|
fn length(self : CharBuffer) -> Int {
  self.view.length() - self.readerIndex
}

///|
fn position(self : CharBuffer) -> Int {
  self.readerIndex
}

///|
fn mark(self : CharBuffer) -> Unit {
  self.mark = self.position()
}

///|
fn reset(self : CharBuffer) -> Unit {
  self.readerIndex = self.mark
}

///|
const WHITESPACE_CHAR = "\n\t "

///|
fn skip_next_whitespace(self : CharBuffer) -> Unit {
  for i = 0; i < self.length(); i = i + 1 {
    let char = self.char_at(i).unwrap()
    if WHITESPACE_CHAR.contains_char(char) {
      continue
    }
    self.readerIndex = self.readerIndex + i
    return
  }
}

///|
fn next_char(self : CharBuffer) -> Char? {
  guard self.ensureCapacity(1) else { return None }
  let result = self.view.get_char(self.readerIndex)
  self.readerIndex += 1
  result
}

///|
fn move_backward(self : CharBuffer) -> Bool {
  guard self.readerIndex != 0 else { return false }
  self.readerIndex -= 1
  true
}

///|
fn has_remaining(self : CharBuffer) -> Bool {
  self.ensureCapacity(1)
}

///|
fn char_at(self : CharBuffer, index : Int) -> Char? {
  self.view.get_char(self.readerIndex + index)
}

///|
fn peek(self : CharBuffer) -> Char? {
  self.view.get_char(self.readerIndex)
}

///|
fn next_string(self : CharBuffer, len : Int) -> @string.View raise {
  guard self.ensureCapacity(len) else {
    raise EndOfString(
      "The requested length \{len} is longer than actual remaining: \{self.view.char_length()}",
    )
  }
  let result = self.view[self.readerIndex:self.readerIndex + len]
  self.readerIndex += len
  result
}
