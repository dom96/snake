import gamelight/vec
type
  FoodKind* = enum
    Nibble, Special

  Food* = ref object
    kind*: FoodKind
    pos*: Point[float] ## Position in level. Not in pixels but segment units.
    ticksLeft*: int ## Amount of updates until food disappears.
