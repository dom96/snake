import times, json

import gamelight/[vec, geometry]

import food

type
  ReplayEventKind* = enum
    FoodAppeared, FoodEaten, DirectionChanged

  ReplayEvent* = object
    time*: float ## measured in seconds
    case kind*: ReplayEventKind
    of FoodAppeared, FoodEaten:
      foodPos*: Point[float] ## in segment units
      foodKind*: FoodKind
    of DirectionChanged:
      playerPos*: Point[float]
      playerDirection*: Direction

  Replay* = ref object
    events*: seq[ReplayEvent]

proc newReplay*(): Replay =
  return Replay(
    events: @[]
  )

proc recordNewFood*(replay: Replay, pos: Point[float], kind: FoodKind) =
  replay.events.add(
    ReplayEvent(
      time: epochTime(),
      kind: FoodAppeared,
      foodPos: pos,
      foodKind: kind
    )
  )

proc recordFoodEaten*(replay: Replay, pos: Point[float], kind: FoodKind) =
  replay.events.add(
    ReplayEvent(
      time: epochTime(),
      kind: FoodEaten,
      foodPos: pos,
      foodKind: kind
    )
  )

proc recordNewDirection*(replay: Replay, pos: Point[float],
                         direction: Direction) =
  replay.events.add(
    ReplayEvent(
      time: epochTime(),
      kind: DirectionChanged,
      playerPos: pos,
      playerDirection: direction
    )
  )

proc `$`*(replay: Replay): string =
  return $(%replay)

proc validate*(replay: Replay): bool =
  if replay.isNil:
    return false

  # TODO: More sophisticated automatic verification.
  return true