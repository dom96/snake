import jsconsole, random, strutils

import gamelight/[graphics, geometry, vec]

type
  Game* = ref object
    renderer: Renderer2D
    player: Snake
    food: array[2, Food]
    score: int
    tick: int

  Snake = ref object
    direction: Direction
    requestedDirection: Direction
    body: seq[SnakeSegment]
    alive: bool

  SnakeSegment = ref object
    pos: Point ## Position in level. Not in pixels but segment units.

  FoodKind = enum
    Apple, Cherry

  Food = ref object
    kind: FoodKind
    pos: Point ## Position in level. Not in pixels but segment units.

const
  segmentSize = 10 ## In pixels
  levelWidth = 30 ## In segments
  levelHeight = 18 ## In Segments
  renderWidth = segmentSize * levelWidth ## In pixels
  renderHeight = segmentSize * levelHeight ## In pixels

proc newSnakeSegment(pos: Point): SnakeSegment =
  result = SnakeSegment(
    pos: pos
  )

proc toPixelPos(pos: Point): Point =
  assert pos.x <= levelWidth
  assert pos.y <= levelHeight
  return pos * segmentSize

proc newSnake(): Snake =
  let head = newSnakeSegment((0, levelHeight div 2))

  result = Snake(
    direction: dirEast,
    requestedDirection: dirEast,
    body: @[head],
    alive: true
  )

proc head(snake: Snake): SnakeSegment =
  snake.body[0]

proc generateFoodPos(game: Game): Point =
  result = (random(0 .. levelWidth), random(0 .. levelHeight))

proc createFood(game: Game, kind: FoodKind, foodIndex: int) =
  let pos = generateFoodPos(game)

  game.food[foodIndex] = Food(kind: kind, pos: pos)

proc newGame*(): Game =
  randomize()
  result = Game(
    renderer: newRenderer2D("canvas", renderWidth, renderHeight),
    player: newSnake()
  )

  result.createFood(Apple, 0)

proc changeDirection*(game: Game, direction: Direction) =
  if game.player.direction.toPoint() == -direction.toPoint():
    return # Disallow changing direction in opposite direction of travel.

  game.player.requestedDirection = direction

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

proc update*(game: Game, ticks: int) =
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
  game.player.direction = game.player.requestedDirection

  # Save old position of head.
  var oldPos = game.player.head.pos.copy()

  # Move head in the current direction.
  let movementVec = game.player.direction.toPoint() * ticks
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

proc draw*(game: Game) =
  game.renderer.fillRect(0, 0, renderWidth, renderHeight, "#b2bd08")

  var drawSnake = true
  if (not game.player.alive) and game.tick mod 4 == 0:
    drawSnake = false

  if drawSnake:
    for segment in game.player.body:
      let pos = segment.pos.toPixelPos()
      game.renderer.fillRect(pos.x, pos.y, segmentSize, segmentSize, "#000000")

  # Draw the food.
  for i in 0 .. game.food.high:
    if not game.food[i].isNil:
      var pos = game.food[i].pos.toPixelPos()
      pos.y += segmentSize
      let emoji =
        case game.food[i].kind
        of Apple: "🍎"
        of Cherry: "🍒"
      game.renderer.fillText(emoji, pos, font="$1px Helvetica" % $segmentSize)