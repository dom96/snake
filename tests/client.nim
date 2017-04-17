import asyncdispatch, os, random

import gamelight/vec
import websocket

import ../snake/[message, replay, food]

proc createConnection(ip: string, i: int) {.async.} =
  let ws = await newAsyncWebsocket(ip, Port(25473), "", ssl = false,
                                   protocols = @["snake"])
  echo(i, " connected")
  proc reader() {.async.} =
    while true:
      let read = await ws.sock.readData(true)
      #echo "read: " & $read

  proc ping() {.async.} =
    while true:
      await sleepAsync(6000)
      await ws.sock.sendPing(true)

  proc sendMessages() {.async.} =
    var replay = newReplay()
    await ws.sock.sendText(toJson(createHelloMessage("bot" & $i, nil)), true)
    for i in 0 .. 90:
      let msg = toJson(createReplayEventMessage(
        replay.recordFoodEaten((0.0, 0.0), Nibble)
      ))
      await sleepAsync(random(800 .. 4000))
      await ws.sock.sendText(msg, true)

  asyncCheck reader()
  asyncCheck ping()
  asyncCheck sendMessages()

when isMainModule:
  let ip = paramStr(1)
  randomize()
  for i in 0 .. 100:
    asyncCheck createConnection(ip, i)
  runForever()