import gamelight/vec
type
  FoodKind* = enum
    Nibble, Special

  Food* = ref object
    kind*: FoodKind
    pos*: Point[float] ## Position in level. Not in pixels but segment units.
    ticksLeft*: int ## Amount of updates until food disappears.


proc getPoints*(kind: FoodKind): int =
  case kind
  of Nibble:
    return 1
  of Special:
    return 5