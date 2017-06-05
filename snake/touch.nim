import dom, jsconsole

import gamelight/[vec, geometry]


proc getDirRects*(canvasId: string, lastDirection: Direction,
                  headPixelPos: Point[int]): (Rect[int], Rect[int], Rect[int]) =
  let snakeCanvas = document.getElementById(canvasId).HtmlElement
  let canvasRect = (
    left: snakeCanvas.offsetLeft, top: snakeCanvas.offsetTop,
    width: snakeCanvas.offsetWidth, height: snakeCanvas.offsetHeight
  )
  # Use the current direction of the snake to make a good decision.
  case lastDirection
  of dirNorth, dirSouth:
    let leftRect = (
      left: canvasRect.left, top: canvasRect.top,
      width: headPixelPos.x, height: canvasRect.height
    )
    let rightRect = (
      left: leftRect.left + leftRect.width, top: leftRect.top,
      width: canvasRect.width, height: leftRect.height
    )

    return (Rect[int](canvasRect), Rect[int](leftRect), rightRect)
  of dirEast, dirWest:
    let topRect = (
      left: canvasRect.left, top: canvasRect.top,
      width: canvasRect.width, height: headPixelPos.y
    )
    let bottomRect = (
      left: topRect.left, top: topRect.top + topRect.height,
      width: topRect.width, height: canvasRect.height
    )

    return (Rect[int](canvasRect), Rect[int](topRect), bottomRect)

proc detectTouch*(canvasId: string, event: TouchEvent,
                  lastDirection: Direction,
                  headPixelPos: Point[int]): (bool, Direction) =
  let (canvasRect, r1, r2) = getDirRects(canvasId, lastDirection, headPixelPos)

  let touch = event.touches.item(0)
  let touchPoint = (touch.clientX, touch.clientY)
  if canvasRect.intersect(touchPoint):
    # Use the current direction of the snake to make a good decision.
    case lastDirection
    of dirNorth, dirSouth:
      let intersectsLeft = r1.intersect(touchPoint)
      let intersectsRight = r2.intersect(touchPoint)
      if intersectsLeft and intersectsRight:
        return
      if intersectsLeft:
        return (true, dirWest)
      if intersectsRight:
        return (true, dirEast)
    of dirEast, dirWest:
      let intersectsTop = r1.intersect(touchPoint)
      let intersectsBottom = r2.intersect(touchPoint)
      if intersectsTop and intersectsBottom:
        return
      if intersectsTop:
        return (true, dirNorth)
      if intersectsBottom:
        return (true, dirSouth)