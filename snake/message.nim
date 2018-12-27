import json, algorithm, sugar, strutils

# TODO: It's annoying that we need to import these for FoodKind and Point...
import gamelight/[vec, geometry], food

import replay

type
  MessageType* {.pure.} = enum
    Hello, ClientUpdate, PlayerUpdate, ReplayEvent, GetReplay, Replay

  Player* = object
    nickname*: string
    score*: BiggestInt
    alive*, paused*: bool
    countryCode*: string

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
    of MessageType.GetReplay:
      dummy, dummy2, dummy3: int
    # Server messages
    of MessageType.PlayerUpdate:
      players*: seq[Player]
      count*: int
      top*: Player
    of MessageType.Replay:
      oldReplay*: Replay

proc `$`*(player: Player): string =
  return "Player(nick: $1, score: $2, alive: $3, paused: $4)" % [
    player.nickname, $player.score, $player.alive, $player.paused
  ]

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

  let selection = sorted[0 ..< min(sorted.len, 5)]

  return Message(
    kind: MessageType.PlayerUpdate,
    players: selection,
    count: players.len,
    top: top
  )

proc createGetReplayMessage*(): Message =
  return Message(
    kind: MessageType.GetReplay
  )

proc createReplayMessage*(replay: Replay): Message =
  return Message(
    kind: MessageType.Replay,
    oldReplay: replay
  )

proc initPlayer*(countryCode: string): Player =
  Player(nickname: "Unknown", score: 0, countryCode: countryCode)