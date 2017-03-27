import asyncdispatch, os, random

import websocket

import ../snake/message

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
    await ws.sock.sendText(toJson(createHelloMessage("bot" & $i)), true)
    for i in 0 .. 90:
      let msg = toJson(createScoreUpdateMessage(i, alive=true, paused=false))
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