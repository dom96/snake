import json, algorithm, future

# TODO: It's annoying that we need to import these for FoodKind and Point...
import gamelight/[vec, geometry], food

import replay

type
  MessageType* {.pure.} = enum
    Hello, ScoreUpdate, PlayerUpdate,
    RecordNewFood, RecordFoodEaten, RecordNewDirection

  Player* = object
    nickname*: string
    score*: BiggestInt
    alive*, paused*: bool

  Message* = object
    case kind*: MessageType
    # Client messages
    of MessageType.Hello:
      nickname*: string
      replay*: Replay ## Optional
    of MessageType.ScoreUpdate:
      score*: BiggestInt
      alive*: bool
      paused*: bool
    of MessageType.RecordNewFood, MessageType.RecordFoodEaten:
      foodPos*: Point[float]
      foodKind*: FoodKind
    of MessageType.RecordNewDirection:
      dirPos*: Point[float]
      dir*: Direction
    # Server messages
    of MessageType.PlayerUpdate:
      players*: seq[Player]
      count*: int
      top*: Player


# TODO: Use marshal module.

proc parsePlayer*(player: JsonNode): Player =
  Player(
    nickname: player["nickname"].getStr,
    score: player["score"].getNum(),
    alive: player["alive"].getBVal(),
    paused: player["paused"].getBVal()
  )

proc parseMessage*(data: string): Message =
  let json = parseJson(data)

  result = to(json, Message)

proc `%`(player: Player): JsonNode =
  %{
        "nickname": %player.nickname,
        "score": %player.score,
        "alive": %player.alive,
        "paused": %player.paused
   }

proc toJson*(message: Message): string =
  var json = %message

  result = $json

proc createHelloMessage*(nickname: string, replay: Replay): Message =
  Message(kind: MessageType.Hello, nickname: nickname, replay: replay)

proc createScoreUpdateMessage*(score: int, alive, paused: bool): Message =
  Message(kind: MessageType.ScoreUpdate, score: score, alive: alive,
          paused: paused)

proc createPlayerUpdateMessage*(players: seq[Player], top: Player): Message =
  # Sort by high score.
  let sorted = sorted(players, (x, y: Player) => cmp(x.score, y.score),
                      Descending)

  let selection = sorted[0 .. <min(sorted.len, 5)]

  return Message(
    kind: MessageType.PlayerUpdate,
    players: selection,
    count: players.len,
    top: top
  )

proc initPlayer*(): Player =
  Player(nickname: "Unknown", score: 0)