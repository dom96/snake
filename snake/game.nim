import jsconsole, random, strutils, dom, math, colors, deques, htmlgen

import gamelight/[graphics, geometry, vec]
import jswebsockets

import message

type
  Game* = ref object
    renderer: Renderer2D
    player: Snake
    food: array[2, Food]
    score: int
    lastUpdate, lastBlink: float
    paused: bool
    blink: bool
    scoreElement: Element
    messageElement: Element
    playerCountElement: Element
    highScoreElements: array[5, Element]
    players: seq[Player]
    playersCount: int
    socket: WebSocket

  Snake = ref object
    direction: Direction
    requestedDirections: Deque[Direction]
    body: seq[SnakeSegment]
    alive: bool

  SnakeSegment = ref object
    pos: Point[float] ## Position in level. Not in pixels but segment units.

  FoodKind = enum
    Apple, Cherry

  Food = ref object
    kind: FoodKind
    pos: Point[float] ## Position in level. Not in pixels but segment units.

const
  segmentSize = 10 ## In pixels
  levelWidth = 30.0 ## In segments
  levelHeight = 18.0 ## In Segments
  scoreSidebarWidth = 100.0
  renderWidth = segmentSize * levelWidth + scoreSidebarWidth ## In pixels
  renderHeight = segmentSize * levelHeight ## In pixels

const
  levelBgColor = "#b2bd08"
  font = "Snake"
  blinkTime = 800 # ms

proc newSnakeSegment(pos: Point[float]): SnakeSegment =
  result = SnakeSegment(
    pos: pos
  )

proc toPixelPos(pos: Point[float]): Point[float] =
  assert pos.x <= levelWidth
  assert pos.y <= levelHeight
  return pos * segmentSize

proc newSnake(): Snake =
  let head = newSnakeSegment((0.0, levelHeight / 2))
  let segment = newSnakeSegment((-1.0, levelHeight / 2))
  let segment2 = newSnakeSegment((-2.0, levelHeight / 2))

  result = Snake(
    direction: dirEast,
    requestedDirections: initDeque[Direction](),
    body: @[head, segment, segment2],
    alive: true
  )

proc head(snake: Snake): SnakeSegment =
  snake.body[0]

proc generateFoodPos(game: Game): Point[float] =
  result = (
    random(0 .. levelWidth.int).float,
    random(0 .. levelHeight.int).float
  )

proc processMessage(game: Game, data: string) =
  let msg = parseMessage(data)
  case msg.kind
  of MessageType.PlayerUpdate:
    console.log("Received ", msg.count, " players")
    game.players = msg.players
    game.playersCount = msg.count

    # Update message in UI.
    let count = $(game.playersCount-1)
    game.playerCountElement.innerHtml = count & " others playing"

    # Update high score labels.
    for i in 0 .. <min(game.players.len, 5):
      let player = game.players[i]
      let text = span(player.nickname.toLowerAscii(), style="float: left;") &
                 span(intToStr(player.score.int), style="float: right;")
      game.highScoreElements[i].innerHTML = text

  of MessageType.Hello, MessageType.ScoreUpdate: discard

proc createFood(game: Game, kind: FoodKind, foodIndex: int) =
  let pos = generateFoodPos(game)

  game.food[foodIndex] = Food(kind: kind, pos: pos)

proc newGame*(): Game =
  randomize()
  result = Game(
    renderer: newRenderer2D("canvas", renderWidth.int, renderHeight.int),
    player: newSnake(),
    players: @[]
  )

  # Create text element nodes to show score and other messages.
  let scoreTextPos = (renderWidth - scoreSidebarWidth + 25, 10.0)
  discard result.renderer.createTextElement("score", scoreTextPos, "#000000",
                                            "24px " & font)
  let scorePos = (renderWidth - scoreSidebarWidth + 25, 35.0)
  result.scoreElement = result.renderer.createTextElement("0000000", scorePos,
                         "#000000", "14px " & font)
  let messageTextPos = (renderWidth - scoreSidebarWidth + 23, 70.0)
  result.messageElement = result.renderer.createTextElement("game<br/>over",
                           messageTextPos, "#000000", "26px " & font)
  let playerCountPos = (renderWidth - scoreSideBarWidth + 15,
                        renderHeight - 25.0)
  result.playerCountElement = result.renderer.createTextElement("",
                              playerCountPos, "#1d1d1d", "12px " & font)
  for i in 0 .. result.highScoreElements.high:
    let y = (i.float * 15.0) + 30.0
    let pos = (renderWidth - scoreSideBarWidth + 15,
               scorePos[1] + y)
    result.highScoreElements[i] = result.renderer.createTextElement("",
        pos, "#2d2d2d", "12px " & font)
    let width = scoreSideBarWidth - 30
    result.highScoreElements[i].style.width = $width & "px"

  # Create first nibble.
  result.createFood(Apple, 0)

  # Set up WebSocket connection.
  var capturedResult = result
  result.socket = newWebSocket("ws://localhost:8080", "snake")

  result.socket.onOpen =
    proc (e: Event) =
      console.log("Connected to server")
      let msg = createHelloMessage("Dom")
      capturedResult.socket.send(toJson(msg))

  result.socket.onMessage =
    proc (e: MessageEvent) =
      processMessage(capturedResult, $e.data)

  result.socket.onClose =
    proc (e: CloseEvent) =
      console.log("Server closed")
      capturedResult.players = @[]

proc changeDirection*(game: Game, direction: Direction) =
  if game.player.requestedDirections.len >= 2:
    return

  game.player.requestedDirections.addLast(direction)

proc processDirections(game: Game) =
  while game.player.requestedDirections.len > 0:
    let direction = game.player.requestedDirections.popFirst()
    if toPoint[float](game.player.direction) == -toPoint[float](direction):
      continue # Disallow changing direction in opposite direction of travel.

    if direction != game.player.direction:
      game.player.direction = direction
      break

proc detectHeadCollision(game: Game): bool =
  # Check if head collides with any other segment.
  for i in 1 .. <game.player.body.len:
    if game.player.head.pos == game.player.body[i].pos:
      return true

proc detectFoodCollision(game: Game): int =
  # Check if head collides with food.
  for i in 0 .. <game.food.len:
    if game.food[i].isNil:
      continue

    if game.food[i].pos == game.player.head.pos:
      return i

  return -1

proc eatFood(game: Game, foodIndex: int) =
  let tailPos = game.player.body[^1].pos.copy()
  game.player.body.add(newSnakeSegment(tailPos))

  case game.food[foodIndex].kind
  of Apple:
    game.score += 1
  of Cherry:
    game.score += 5
  game.food[foodIndex] = nil

  game.createFood(Apple, 0)

  # Update score element.
  game.scoreElement.innerHTML = intToStr(game.score, 7)

  # Update server.
  let msg = createScoreUpdateMessage(game.score)
  game.socket.send(toJson(msg))

proc update(game: Game) =
  # Return early if paused.
  if game.paused: return

  # Check for collision with itself.
  let headCollision = game.detectHeadCollision()
  if headCollision:
    game.player.alive = false
    game.messageElement.innerHtml = "game<br/>over"
    return

  # Check for food collision.
  let foodCollision = game.detectFoodCollision()
  if foodCollision != -1:
    game.eatFood(foodCollision)

  # Change direction.
  processDirections(game)

  # Save old position of head.
  var oldPos = game.player.head.pos.copy()

  # Move head in the current direction.
  let movementVec = toPoint[float](game.player.direction)
  game.player.head.pos.add(movementVec)

  # Move each body segment with the head.
  for i in 1 .. <game.player.body.len:
    swap(game.player.body[i].pos, oldPos)

  # Create a portal out of the edges of the level.
  if game.player.head.pos.x >= levelWidth:
    game.player.head.pos.x = 0
  elif game.player.head.pos.x < 0:
    game.player.head.pos.x = levelWidth

  if game.player.head.pos.y >= levelHeight:
    game.player.head.pos.y = 0
  elif game.player.head.pos.y < 0:
    game.player.head.pos.y = levelHeight

proc drawFood(game: Game, food: Food) =
  const nibble = [
    0, 0, 0, 1, 1, 1, 1, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 0, 0, 0,
    1, 1, 1, 0, 0, 0, 0, 1, 1, 1,
    1, 1, 1, 0, 0, 0, 0, 1, 1, 1,
    1, 1, 1, 0, 0, 0, 0, 1, 1, 1,
    1, 1, 1, 0, 0, 0, 0, 1, 1, 1,
    0, 0, 0, 1, 1, 1, 1, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 0, 0, 0,
    0, 0, 0, 1, 1, 1, 1, 0, 0, 0,
  ]
  var pos = food.pos.toPixelPos()
  for x in 0 .. <segmentSize:
    for y in 0 .. <segmentSize:
      if nibble[x + (y * segmentSize)] == 1:
        game.renderer[(pos.x + x.float, pos.y + y.float)] = colBlack

proc drawEyes(game: Game) =
  let angle = game.player.direction.angle
  let headPos = game.player.head.pos.toPixelPos()
  let headMiddle = headPos + ((segmentSize-1) / 2, (segmentSize-1) / 2)

  let eyeTop = (headPos.x + 5.0, headPos.y + 2).toPoint()
  let eyeBot = (headPos.x + 5.0, headPos.y + 6).toPoint()

  for eye in [eyeTop, eyeBot]:
    let rect = [
      (eye.x    , eye.y    ).toPoint().rotate(angle, headMiddle),
      (eye.x + 1, eye.y    ).toPoint().rotate(angle, headMiddle),
      (eye.x    , eye.y + 1).toPoint().rotate(angle, headMiddle),
      (eye.x + 1, eye.y + 1).toPoint().rotate(angle, headMiddle)
    ]
    for point in rect:
      game.renderer[point] = colWhite

proc draw(game: Game, lag: float) =
  # Fill background color.
  game.renderer.fillRect(0.0, 0.0, renderWidth, renderHeight, levelBgColor)

  # Determines whether the Game Over/Paused message should be shown.
  let showMessage = not game.player.alive or game.paused

  # Draw the food.
  for i in 0 .. game.food.high:
    if not game.food[i].isNil:
      game.drawFood(game.food[i])

  # Draw snake.
  if not (game.blink and showMessage):
    for i in 0 .. <game.player.body.len:
      let segment = game.player.body[i]
      let pos = segment.pos.toPixelPos()
      game.renderer.fillRect(pos.x, pos.y, segmentSize, segmentSize, "#000000")

    game.drawEyes()

  # Draw the scoreboard.
  game.renderer.fillRect(renderWidth - scoreSidebarWidth, 0, scoreSidebarWidth,
                         renderHeight, levelBgColor)

  game.renderer.strokeRect(renderWidth - scoreSidebarWidth, 5,
                           scoreSidebarWidth - 5, renderHeight - 10,
                           lineWidth = 2)

  # Show/hide high scores.
  for element in game.highScoreElements:
    element.style.display = if showMessage: "none" else: "block"

  if game.blink and showMessage:
    game.messageElement.style.display = "block"
  else:
    game.messageElement.style.display = "none"

proc getTickLength(game: Game): float =
  result = 200.0
  if game.player.alive:
    result -= game.score.float

proc nextFrame*(game: Game, frameTime: float) =
  # Determine whether we should update.
  let elapsedTime = frameTime - game.lastUpdate

  let ticks = floor(elapsedTime / game.getTickLength).int
  let lag = (elapsedTime / game.getTickLength) - ticks.float
  if elapsedTime > game.getTickLength:
    game.lastUpdate = frameTime
    for tick in 0 .. <ticks:
      game.update()

  # Blink timer.
  let elapsedBlinkTime = frameTime - game.lastBlink
  if elapsedBlinkTime > blinkTime:
    game.lastBlink = frameTime
    game.blink = not game.blink

  game.draw(lag)

proc togglePause*(game: Game) =
  if not game.player.alive: return
  game.paused = not game.paused
  game.messageElement.innerHtml = "paused"