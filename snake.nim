import dom, jsconsole, sugar

import gamelight/[geometry, utils]

import snake/[game, keyboard, touch]

const
  canvasId = "snake_canvas"

type
  KeyboardEvent = ref object of Event
    metaKey: bool

proc onKeydown(game: Game, ev: Event) =
  var ev = KeyboardEvent(ev)
  console.log(ev.keyCode)
  let key = ev.keyCode.fromKeyCode()
  console.log("Pressed: ", $key)
  if ev.shiftKey or ev.ctrlKey or ev.altKey or ev.metaKey:
    return

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
  of Key.KeyN:
    game.restart()
  of Key.KeyR:
    game.replay()
  else:
    handled = false

  if handled:
    ev.preventDefault()

proc onTouch(game: Game, ev: TouchEvent) =
  let lastDir = game.getLastDirection()
  let headPixelPos = game.getHeadPixelPos()
  let (touched, direction) = detectTouch(canvasId, ev, lastDir, headPixelPos)

  if touched:
    game.changeDirection(direction)

  if game.isScaledToScreen():
    ev.preventDefault()
    ev.target.Element.click()

proc onTick(game: Game, time: float) =
  discard window.requestAnimationFrame((time: float) => onTick(game, time))

  game.nextFrame(time)

proc onGameStart(game: Game) =
  window.addEventListener("keydown", (ev: Event) => onKeydown(game, ev))
  window.addEventListener("touchstart", (ev: Event) => onTouch(game, ev.TouchEvent),
                          AddEventListenerOptions(passive: false))

proc onLoad(event: Event) {.exportc.} =
  var game = newGame(canvasId)
  game.onGameStart = onGameStart

  if isTouchDevice():
    # Hide keyboard control cheatsheet.
    document.querySelector("#snake_controls").style.display = "none"

  onTick(game, 16)

window.onload = onLoad