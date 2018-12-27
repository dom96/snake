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

proc add*(replay: Replay, event: ReplayEvent) =
  replay.events.add(event)

proc recordNewFood*(replay: Replay, pos: Point[float],
                    kind: FoodKind): ReplayEvent =
  result =
    ReplayEvent(
      time: epochTime(),
      kind: FoodAppeared,
      foodPos: pos,
      foodKind: kind
    )
  replay.events.add(result)

proc recordFoodEaten*(replay: Replay, pos: Point[float],
                      kind: FoodKind): ReplayEvent =
  result =
    ReplayEvent(
      time: epochTime(),
      kind: FoodEaten,
      foodPos: pos,
      foodKind: kind
    )

  replay.events.add(result)

proc recordNewDirection*(replay: Replay, pos: Point[float],
                         direction: Direction): ReplayEvent =
  result =
    ReplayEvent(
      time: epochTime(),
      kind: DirectionChanged,
      playerPos: pos,
      playerDirection: direction
    )
  replay.events.add(result)

proc getScore*(replay: Replay): int =
  result = 0
  for event in replay.events:
    case event.kind
    of FoodEaten:
      result += getPoints(event.foodKind)
    else:
      discard

proc `$`*(replay: Replay): string =
  return $(%replay)

proc validate*(replay: Replay): bool =
  if replay.isNil:
    return false

  # TODO: More sophisticated automatic verification.
  return true

proc parseReplay*(data: string): Replay =
  let d = parseJson(data)
  return to(d, Replay)