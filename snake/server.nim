import asyncdispatch, asynchttpserver, asyncnet, future, logging, strutils, os
import times

import websocket

import message

type
  Client = ref object
    socket: AsyncSocket
    connected: bool
    player: Player

  Server = ref object
    clients: seq[Client]
    needsUpdate: bool
    top: Player ## Highest score ever.

proc newClient(socket: AsyncSocket): Client =
  return Client(
    socket: socket,
    connected: true,
    player: initPlayer()
  )

proc `$`(client: Client): string =
  return "Client(nickname: $1, score: $2)" %
      [client.player.nickname, $client.player.score]

proc getTopScoresFilename(): string = getCurrentDir() / "topscores.snake"

proc updateClients(server: Server) {.async.} =
  ## Updates each client with the current player scores every second.
  while true:
    if server.needsUpdate:
      info("Updating")
      var newClients: seq[Client] = @[]
      var players: seq[Player] = @[]
      for client in server.clients:
        if not client.connected: continue

        players.add(client.player)
        newClients.add(client)

      # Overwrite with new list containing only connected clients.
      server.clients = newClients

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

    # Save to topscore.snake.
    let filename = getTopScoresFilename()
    let file = open(filename, fmAppend)
    let time = getGMTime(getTime()).format("yyyy-MM-dd HH:mm:ss")
    file.write("$1\t$2\t$3\n" %
        [server.top.nickname, $server.top.score, time])

proc processMessage(server: Server, client: Client, data: string) {.async.} =
  ## Process a single message.
  let msg = parseMessage(data)
  case msg.kind
  of MessageType.Hello:
    client.player.nickname = msg.nickname
    # Verify nickname is valid.
    # TODO: Check for swear words? :)
    if client.player.nickname.len < 2:
      warn("Nickname too short, changing to Anon")
      client.player.nickname = "Anon"
    if client.player.nickname.len > 8:
      warn("Nickname too long, truncating")
      client.player.nickname = client.player.nickname[0 .. 8]
  of MessageType.ScoreUpdate:
    client.player.score = msg.score
    # Validate score.
    if client.player.score.int notin 0 .. 9999:
      warn("Bad score for ", $client)
      client.player.score = 0
      client.connected = false

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
      await processMessage(server, client, frame.data)

  client.socket.close()

proc onRequest(server: Server, req: Request) {.async.} =
  let (success, error) = await verifyWebsocketRequest(req, "snake")
  if success:
    info("Client connected")
    server.clients.add(newClient(req.client))
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
      score: split[1].parseInt()
    )
  else:
    info("No topscores.snake file found")
    server.top = Player(
      nickname: "",
      score: 0
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