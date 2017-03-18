import gamelight/[graphics, geometry, vec]

type
  Game* = ref object
    renderer: Renderer2D
    player: Snake

  Snake* = ref object
    direction: Direction
    body: seq[SnakeSegment]

  SnakeSegment* = ref object
    pos: Point

proc newSnake*(): Snake =
  result = Snake(
    direction: dirEast
  )

proc head*(snake: Snake): SnakeSegment =
  snake.body[0]

proc newGame*(): Game =
  result = Game(
    renderer: newRenderer2D("canvas", 300, 200),
    player: newSnake()
  )

proc changeDirection*(game: Game, direction: Direction) =
  if game.player.direction.toPoint() == -direction.toPoint():
    return # Disallow changing direction in opposite direction of travel.

  game.player.direction = direction

proc update*(game: Game, ticks: int) =
  let movementVec = game.player.direction.toPoint() * ticks
  game.player.head.pos.add(movementVec)

  for i in 1 .. <game.player.body.len:
    game.player.body[i].pos = game.player.body[i-1].pos

