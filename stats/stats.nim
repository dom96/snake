# Processes a JSON log file retrieved by running:
# sudo journalctl -S 2018-03-16 --utc -u snake -o json > snake_logs.json
#
# Outputs a CSV file.

import json, times, strutils, parseutils

type
  EventKind = enum
    Unknown, Connection, Error, Traceback, Disconnection, Warning, Exited, Started

  Event = object
    timestamp: Time
    case kind: EventKind
    of Unknown: discard
    of Connection:
      ip: string
      country: string
    of Error, Traceback, Warning:
      msg: string
    of Disconnection, Started: discard
    of Exited:
      exitCode: int

proc parse(s: string): Event =
  let j = parseJson(s)
  let timestamp = j["__REALTIME_TIMESTAMP"].getStr().parseInt() div 1000 div 1000
  result.timestamp = fromUnix(timestamp)

  let msg = j["MESSAGE"].getStr()
  if msg.startsWith("INFO"):
    # INFO 2018-03-16T02:02:41 Client connected from 222.212.21.37 CN
    const connectionMarker = "Client connected from "
    var index = msg.find(connectionMarker)
    if index != -1:
      result.kind = Connection
      index += connectionMarker.len
      index += parseUntil(msg, result.ip, Whitespace, index)
      index += skipWhitespace(msg, index)
      index += parseUntil(msg, result.country, {'\0'}, index)
      return
  elif msg.startsWith("ERROR"):
    result.kind = Error
    result.msg = msg
    return
  elif msg.startsWith("WARN"):
    result.kind = Warning
    result.msg = msg
    return
  elif msg.startsWith("  "):
    result.kind = Traceback
    result.msg = msg
    return
  elif msg == "socket closed" or msg == "socket closed by remote peer":
    result.kind = Disconnection
    return
  elif msg == "value out of range: -31213" or msg == "value out of range: -30639":
    result.kind = Error
    result.msg = msg
    return
  elif msg.startsWith("snake.service: Main process exited"):
    result.kind = Exited
    result.exitCode = j["EXIT_STATUS"].getStr().parseInt()
    return
  elif msg == "Started snake.":
    result.kind = Started
    return

  echo("Unknown: ", msg)

when isMainModule:
  var logs = readFile("2018-03-16_logs.json")

  var csv = "time,ip,country,count\n"
  var clientCount = 0
  for line in logs.splitLines():
    if line.len > 0:
      let parsed = parse(line)
      const formatStr = "yyyy-MM-dd HH:mm:ss"

      case parsed.kind
      of Connection:
        clientCount.inc()
        csv.add([parsed.timestamp.inZone(utc()).format(formatStr),
                 parsed.ip, parsed.country,
                 $clientCount].join(",") & "\n")
      of Disconnection:
        clientCount.dec()
        csv.add([parsed.timestamp.inZone(utc()).format(formatStr),
                 "", "", $clientCount].join(",") & "\n")
      of Exited:
        clientCount = 0
        csv.add([parsed.timestamp.inZone(utc()).format(formatStr),
                 "", "", $clientCount].join(",") & "\n")
      of Error:
        if parsed.msg.startsWith("value out of range:"):
          clientCount.dec()
          csv.add([parsed.timestamp.inZone(utc()).format(formatStr),
                   "", "", $clientCount].join(",") & "\n")
      else: discard

  writeFile("2018-03-16_logs.csv", csv)

