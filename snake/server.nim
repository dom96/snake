import asyncdispatch, asynchttpserver, asyncnet, future, logging, strutils, os
import times

import websocket

import message, replay, food, countries

type
  Client = ref object
    socket: AsyncSocket
    connected: bool
    hostname: string
    player: Player
    lastMessage: float
    rapidMessageCount: int
    replay: Replay

  Server = ref object
    clients: seq[Client]
    needsUpdate: bool
    top: Player ## Highest score ever.

proc newClient(socket: AsyncSocket, hostname, countryCode: string): Client =
  return Client(
    socket: socket,
    connected: true,
    hostname: hostname,
    player: initPlayer(countryCode),
    replay: newReplay()
  )

proc `$`(client: Client): string =
  return "Client(ip: $1, nickname: $2, score: $3)" %
      [client.hostname, client.player.nickname, $client.player.score]

proc getTopScoresFilename(): string = getCurrentDir() / "topscores.snake"

proc updateClients(server: Server) {.async.} =
  ## Updates each client with the current player scores every second.
  while true:
    var newClients: seq[Client] = @[]
    var players: seq[Player] = @[]
    for client in server.clients:
      if not client.connected: continue

      players.add(client.player)
      newClients.add(client)

    # Overwrite with new list containing only connected clients.
    server.needsUpdate = server.needsUpdate or
        server.clients.len != newClients.len
    server.clients = newClients

    if server.needsUpdate:
      # Send the message to each client.
      let msg = createPlayerUpdateMessage(players, server.top)
      # Iterate over indexes in case a new client connects in-between our calls
      # to `sendText`.
      for i in 0 .. <server.clients.len:
        await server.clients[i].socket.sendText(toJson(msg))

      server.needsUpdate = false

    # Wait for 1 second.
    await sleepAsync(1000)

proc updateTopScore(server: Server, player: Player, hostname: string,
                    replay: Replay) =
  if server.top.score < player.score:
    info("New high score: $1 $2" % [$player, hostname])
    server.top = player
    server.top.alive = true

    # Save to topscore.snake.
    let filename = getTopScoresFilename()
    let file = open(filename, fmAppend)
    let time = getGMTime(getTime()).format("yyyy-MM-dd HH:mm:ss")
    file.write("$1\t$2\t$3\t$4\t$5\n" % [
      server.top.nickname,
      $server.top.score,
      time,
      hostname,
      $replay
    ])
    file.close()

proc isValidScore(server: Server, client: Client): bool =
  result = true
  if client.player.score.int notin 0 .. 9999:
    warn("Bad score for ", $client)
    return false

  # TODO: Send replay updates to server instead of sending full replay at the
  # end.
  # https://security.stackexchange.com/a/148447

  # Verify the replay.
  # if client.player.score > server.top.score:
  #   return replay.validate

proc processMessage(server: Server, client: Client, data: string) {.async.} =
  ## Process a single message.

  # Check if last message was relatively recent. If so, kick the user.
  if epochTime() - client.lastMessage < 0.1: # 100ms
    client.rapidMessageCount.inc
  else:
    client.rapidMessageCount = 0

  client.lastMessage = epochTime()
  if client.rapidMessageCount > 10:
    warn("Client ($1) is firing messages too rapidly. Killing." % $client)
    client.connected = false

  # Parse message.
  let msg = parseMessage(data)
  case msg.kind
  of MessageType.Hello:
    client.player.nickname = msg.nickname
    client.player.alive = true
    client.player.paused = false
    # Verify nickname is valid.
    # TODO: Check for swear words? :)
    if client.player.nickname.len == 0:
      warn("Nickname is empty, changing to Anon")
      client.player.nickname = "Anon"
    if client.player.nickname.len > 8:
      warn("Nickname too long, truncating")
      client.player.nickname = client.player.nickname[0 .. 8]

    # Handle replays.
    if not msg.replay.isNil:
      client.replay = msg.replay
    else:
      client.replay = newReplay()
    client.player.score = client.replay.getScore()

  of MessageType.ClientUpdate:
    client.player.alive = msg.alive
    client.player.paused = msg.paused

  of MessageType.ReplayEvent:
    client.replay.add(msg.replayEvent)

    if msg.replayEvent.kind == FoodEaten:
      client.player.score += getPoints(msg.replayEvent.foodKind)

      # Validate score.
      if not isValidScore(server, client):
        warn("Invalid score for $1" % $client)
        client.player.score = 0
        client.connected = false
        return

      # Update top score
      updateTopScore(server, client.player, client.hostname, client.replay)

  of MessageType.PlayerUpdate:
    # The client shouldn't send this.
    client.connected = false

  server.needsUpdate = true

proc processClient(server: Server, client: Client) {.async.} =
  ## Loop which continuously reads data from the client and processes the
  ## messages which are received.
  while client.connected:
    var frameFut = client.socket.readData()
    yield frameFut
    if frameFut.failed:
      error("Error occurred handling client messages.\n" &
            frameFut.error.msg)
      client.connected = false
      break

    let frame = frameFut.read()
    if frame.opcode == Opcode.Text:
      let processFut = processMessage(server, client, frame.data)
      if processFut.failed:
        error("Client ($1) attempted to send bad JSON? " % $client,
              processFut.error.msg)
        info("The incorrect JSON was: " & frame.data)
        client.connected = false

  client.socket.close()

proc onRequest(server: Server, req: Request) {.async.} =
  let (client, error) = await verifyWebsocketRequest(req, "snake")
  if error.len == 0:
    var hostname = req.hostname
    if req.headers.hasKey("x-forwarded-for"):
      hostname = req.headers["x-forwarded-for"]

    let countryCode = await getCountryForIP(hostname)
    info("Client connected from ", hostname, " ", countryCode)
    server.clients.add(newClient(req.client, hostname, countryCode))
    asyncCheck processClient(server, server.clients[^1])
  else:
    error("WS negotiation failed: " & error)
    await req.respond(Http400, "WebSocket negotiation failed: " & error)
    req.client.close()

proc loadTopScore(server: Server) =
  let filename = getTopScoresFilename()
  if fileExists(filename):
    info("Reading top score from ", filename)
    let topScores = readFile(filename)
    let latest = topScores.splitLines()[^2]
    let split = latest.split("\t")
    server.top = Player(
      nickname: split[0],
      score: split[1].parseInt(),
      alive: true,
      countryCode: waitFor getCountryForIP(split[3])
    )
  else:
    info("No topscores.snake file found")
    server.top = Player(
      nickname: "",
      score: 0,
      alive: true
    )

when isMainModule:
  # Set up logging to console.
  var consoleLogger = newConsoleLogger(fmtStr = "$levelname $datetime ")
  addHandler(consoleLogger)

  # Set up a new `server` instance.
  let httpServer = newAsyncHttpServer()
  let server = Server(
    clients: @[]
  )

  # Load top score.
  loadTopScore(server)

  # Launch the HTTP server.
  const port = Port(25473)
  info("Listening on port ", port.int)

  # TODO: Slightly annoying that I cannot just use future.=> here instead.
  # TODO: Ref https://github.com/nim-lang/Nim/issues/4753
  proc cb(req: Request): Future[void] {.async, gcsafe.} = await onRequest(server, req)

  asyncCheck updateClients(server)
  waitFor httpServer.serve(port, cb)