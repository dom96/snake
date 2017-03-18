import dom, jsconsole, future

import gamelight/geometry

import snake/[game, keyboard]

proc onKeydown(game: Game, ev: Event) =
  let key = ev.keyCode.fromKeyCode()
  console.log("Pressed: ", key)

  var handled = false
  case key
  of Key.UpArrow:
    game.changeDirection(dirNorth)
    handled = true
  of Key.RightArrow:
    game.changeDirection(dirEast)
    handled = true
  of Key.DownArrow:
    game.changeDirection(dirSouth)
    handled = true
  of Key.LeftArrow:
    game.changeDirection(dirWest)
    handled = true
  else:
    discard

  if handled:
    ev.preventDefault()

proc onLoad() {.exportc.} =
  var game = newGame()

  window.addEventListener("keydown", (ev: Event) => onKeydown(game, ev))