import asyncdispatch, asynchttpserver, asyncnet, future, logging, strutils, os
import times

import websocket

import message

type
  Client = ref object
    socket: AsyncSocket
    connected: bool
    hostname: string
    player: Player
    lastMessage: float
    rapidMessageCount: int

  Server = ref object
    clients: seq[Client]
    needsUpdate: bool
    top: Player ## Highest score ever.

proc newClient(socket: AsyncSocket, hostname: string): Client =
  return Client(
    socket: socket,
    connected: true,
    hostname: hostname,
    player: initPlayer()
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
      info("Updating clients")
      # Send the message to each client.
      let msg = createPlayerUpdateMessage(players, server.top)
      for client in server.clients:
        await client.socket.sendText(toJson(msg), false)

      server.needsUpdate = false

    info("$1 clients connected" % $server.clients.len)
    # Wait for 1 second.
    await sleepAsync(1000)

proc updateTopScore(server: Server, player: Player) =
  if server.top.score < player.score:
    server.top = player
    server.top.alive = true

    # Save to topscore.snake.
    let filename = getTopScoresFilename()
    let file = open(filename, fmAppend)
    let time = getGMTime(getTime()).format("yyyy-MM-dd HH:mm:ss")
    file.write("$1\t$2\t$3\n" %
        [server.top.nickname, $server.top.score, time])
    file.close()

proc processMessage(server: Server, client: Client, data: string) {.async.} =
  ## Process a single message.

  # Check if last message was relatively recent. If so, kick the user.
  if epochTime() - client.lastMessage < 0.5: # 500ms
    client.rapidMessageCount.inc
  else:
    client.rapidMessageCount = 0

  client.lastMessage = epochTime()
  if client.rapidMessageCount > 4:
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
    if client.player.nickname.len < 2:
      warn("Nickname too short, changing to Anon")
      client.player.nickname = "Anon"
    if client.player.nickname.len > 8:
      warn("Nickname too long, truncating")
      client.player.nickname = client.player.nickname[0 .. 8]
  of MessageType.ScoreUpdate:
    let diff = msg.score - client.player.score
    if diff < 0 or msg.score > server.top.score or not client.player.alive:
      warn("Client ($1) is cheating" % $client)
      client.connected = false
      return

    client.player.score = msg.score
    client.player.alive = msg.alive
    client.player.paused = msg.paused
    # Validate score.
    if client.player.score.int notin 0 .. 9999:
      warn("Bad score for ", $client)
      client.player.score = 0
      client.connected = false
      return

    # Update top score
    updateTopScore(server, client.player)

  of MessageType.PlayerUpdate:
    # The client shouldn't send this.
    client.connected = false

  server.needsUpdate = true

proc processClient(server: Server, client: Client) {.async.} =
  ## Loop which continuously reads data from the client and processes the
  ## messages which are received.
  while client.connected:
    var frameFut = client.socket.readData(false)
    yield frameFut
    if frameFut.failed:
      error("Error occurred handling client messages.\n" &
            frameFut.error.msg)
      client.connected = false
      break

    let frame = frameFut.read()
    info("Received ", frame.opcode)
    if frame.opcode == Opcode.Text:
      let processFut = processMessage(server, client, frame.data)
      if processFut.failed:
        error("Client ($1) attempted to send bad JSON? " % $client,
              processFut.error.msg)
        client.connected = false

  client.socket.close()

proc onRequest(server: Server, req: Request) {.async.} =
  let (success, error) = await verifyWebsocketRequest(req, "snake")
  if success:
    info("Client connected from ", req.hostname)
    server.clients.add(newClient(req.client, req.hostname))
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
      alive: true
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
  var consoleLogger = newConsoleLogger()
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
  proc cb(req: Request): Future[void] {.async.} = await onRequest(server, req)

  asyncCheck updateClients(server)
  waitFor httpServer.serve(port, cb)