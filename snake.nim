import dom, jsconsole, future

import gamelight/geometry

import snake/[game, keyboard]

proc onKeydown(game: Game, ev: Event) =
  let key = ev.keyCode.fromKeyCode()
  console.log("Pressed: ", $key)

  var handled = true
  case key
  of Key.UpArrow:
    game.changeDirection(dirNorth)
  of Key.RightArrow:
    game.changeDirection(dirEast)
  of Key.DownArrow:
    game.changeDirection(dirSouth)
  of Key.LeftArrow:
    game.changeDirection(dirWest)
  else:
    handled = false

  if handled:
    ev.preventDefault()

proc onTick(game: Game) =
  game.draw()
  game.update(1)

proc onLoad() {.exportc.} =
  var game = newGame()

  window.addEventListener("keydown", (ev: Event) => onKeydown(game, ev))
  discard window.setInterval(() => onTick(game), 200)