type
  Key* {.pure.} = enum
    Unknown = -1, LeftArrow = 37, UpArrow = 38, RightArrow = 39, DownArrow = 40

proc fromKeyCode*(keyCode: int): Key =
  return Key(keyCode) # TODO: