import dom, jsconsole, future

import gamelight/geometry

import snake/[game, keyboard]

proc onKeydown(game: Game, ev: Event) =
  console.log(ev.keyCode)
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
  of Key.KeyP, Key.KeySpace:
    game.togglePause()
  else:
    handled = false

  if handled:
    ev.preventDefault()

proc onTick(game: Game, time: float) =
  let reqId = window.requestAnimationFrame((time: float) => onTick(game, time))

  game.nextFrame(time)

proc onLoad() {.exportc.} =
  var game = newGame()

  window.addEventListener("keydown", (ev: Event) => onKeydown(game, ev))

  onTick(game, 16)