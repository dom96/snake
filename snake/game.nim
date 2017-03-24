import jsconsole, random, strutils, dom, math, colors, deques

import gamelight/[graphics, geometry, vec]

type
  Game* = ref object
    renderer: Renderer2D
    player: Snake
    food: array[2, Food]
    score: int
    tick: int
    lastUpdate: float
    scoreElement: Element
    gameOverElement: Element

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

proc createFood(game: Game, kind: FoodKind, foodIndex: int) =
  let pos = generateFoodPos(game)

  game.food[foodIndex] = Food(kind: kind, pos: pos)

proc newGame*(): Game =
  randomize()
  result = Game(
    renderer: newRenderer2D("canvas", renderWidth.int, renderHeight.int),
    player: newSnake()
  )

  # Create text element nodes to show score and other messages.
  let scoreTextPos = (renderWidth - scoreSidebarWidth + 25, 10.0)
  discard result.renderer.createTextElement("score", scoreTextPos, "#000000",
                                            "24px " & font)
  let scorePos = (renderWidth - scoreSidebarWidth + 25, 35.0)
  result.scoreElement = result.renderer.createTextElement("0000000", scorePos,
                         "#000000", "14px " & font)
  let gameOverTextPos = (renderWidth - scoreSidebarWidth + 23, 70.0)
  result.gameOverElement = result.renderer.createTextElement("game<br/>over",
                           gameOverTextPos, "#000000", "26px " & font)

  result.createFood(Apple, 0)

proc changeDirection*(game: Game, direction: Direction) =
  if game.player.requestedDirections.len >= 2:
    return
  
  game.player.requestedDirections.addLast(direction)

proc processDirections(game: Game) =
  console.log($game.player.requestedDirections)
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

proc update(game: Game) =
  # Used for tracking time.
  game.tick.inc()

  # Check for collision with itself.
  let headCollision = game.detectHeadCollision()
  if headCollision:
    game.player.alive = false
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
  game.renderer.fillRect(0.0, 0.0, renderWidth, renderHeight, levelBgColor)

  var drawSnake = true
  if (not game.player.alive) and game.tick mod 4 == 0:
    drawSnake = false

  # Draw the food.
  for i in 0 .. game.food.high:
    if not game.food[i].isNil:
      var pos = game.food[i].pos.toPixelPos()
      game.drawFood(game.food[i])

  if drawSnake:
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

  if drawSnake:
    game.gameOverElement.style.display = "none"
  else:
    # Snake isn't drawn when game is over, so blink game over text.
    game.gameOverElement.style.display = "block"

proc getTickLength(game: Game): float =
  result = 200.0
  if game.player.alive:
    result -= game.score.float

proc nextFrame*(game: Game, frameTime: float) =
  let elapsedTime = frameTime - game.lastUpdate

  let ticks = floor(elapsedTime / game.getTickLength).int
  let lag = (elapsedTime / game.getTickLength) - ticks.float
  if elapsedTime > game.getTickLength:
    game.lastUpdate = frameTime
    for tick in 0 .. <ticks:
      game.update()

  game.draw(lag)