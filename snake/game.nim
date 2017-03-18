import jsconsole

import gamelight/[graphics, geometry, vec]

type
  Game* = ref object
    renderer: Renderer2D
    player: Snake

  Snake* = ref object
    direction: Direction
    body: seq[SnakeSegment]

  SnakeSegment* = ref object
    pos: Point ## Position in level, not in pixels.

const
  segmentSize = 30 ## In pixels
  levelWidth = 10 ## In segments
  levelHeight = 6 ## In Segments
  renderWidth = segmentSize * levelWidth ## In pixels
  renderHeight = segmentSize * levelHeight ## In pixels

proc newSnakeSegment*(pos: Point): SnakeSegment =
  result = SnakeSegment(
    pos: pos
  )

proc newSnake*(): Snake =
  let head = newSnakeSegment((levelWidth div 2, levelHeight div 2))

  result = Snake(
    direction: dirEast,
    body: @[head]
  )

proc head*(snake: Snake): SnakeSegment =
  snake.body[0]

proc newGame*(): Game =
  result = Game(
    renderer: newRenderer2D("canvas", renderWidth, renderHeight),
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

proc draw*(game: Game) =
  game.renderer.fillRect(0, 0, renderWidth, renderHeight, "#b2bd08")