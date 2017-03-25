type
  Key* {.pure.} = enum
    Unknown = -1, KeySpace = 32, LeftArrow = 37, UpArrow = 38,
    RightArrow = 39, DownArrow = 40, KeyP = 80

proc fromKeyCode*(keyCode: int): Key =
  try:
    return Key(keyCode)
  except RangeError:
    return Key.Unknown