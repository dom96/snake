import json, algorithm, future

# TODO: It's annoying that we need to import these for FoodKind and Point...
import gamelight/[vec, geometry], food

import replay

type
  MessageType* {.pure.} = enum
    Hello, ClientUpdate, PlayerUpdate, ReplayEvent

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
    of MessageType.ClientUpdate:
      alive*: bool
      paused*: bool
    of MessageType.ReplayEvent:
      replayEvent*: ReplayEvent
    # Server messages
    of MessageType.PlayerUpdate:
      players*: seq[Player]
      count*: int
      top*: Player

proc parseMessage*(data: string): Message =
  let json = parseJson(data)

  result = to(json, Message)

proc toJson*(message: Message): string =
  var json = %message

  result = $json

proc createHelloMessage*(nickname: string, replay: Replay): Message =
  Message(kind: MessageType.Hello, nickname: nickname, replay: replay)

proc createClientUpdateMessage*(alive, paused: bool): Message =
  Message(kind: MessageType.ClientUpdate, alive: alive,
          paused: paused)

proc createReplayEventMessage*(event: ReplayEvent): Message =
  Message(
    kind: MessageType.ReplayEvent,
    replayEvent: event
  )

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