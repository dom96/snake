import dom, jsconsole

import gamelight/[vec, geometry]



proc detectTouch*(canvasId: string, event: TouchEvent,
                  lastDirection: Direction): (bool, Direction) =
  let snakeCanvas = document.getElementById(canvasId).HtmlElement
  let touch = event.touches.item(0)
  let canvasRect = (
    left: snakeCanvas.offsetLeft, top: snakeCanvas.offsetTop,
    width: snakeCanvas.offsetWidth, height: snakeCanvas.offsetHeight
  )
  let touchPoint = (touch.clientX, touch.clientY)
  if canvasRect.intersect(touchPoint):
    # Use the current direction of the snake to make a good decision.
    case lastDirection
    of dirNorth, dirSouth:
      let leftRect = (
        left: canvasRect.left, top: canvasRect.top,
        width: canvasRect.width div 2, height: canvasRect.height
      )
      let rightRect = (
        left: leftRect.left + leftRect.width, top: leftRect.top,
        width: leftRect.width, height: leftRect.height
      )
      let intersectsLeft = leftRect.intersect(touchPoint)
      let intersectsRight = rightRect.intersect(touchPoint)
      if intersectsLeft and intersectsRight:
        return
      if intersectsLeft:
        return (true, dirWest)
      if intersectsRight:
        return (true, dirEast)
    of dirEast, dirWest:
      let topRect = (
        left: canvasRect.left, top: canvasRect.top,
        width: canvasRect.width, height: canvasRect.height div 2
      )
      let bottomRect = (
        left: topRect.left, top: topRect.top + topRect.height,
        width: topRect.width, height: topRect.height
      )
      let intersectsTop = topRect.intersect(touchPoint)
      let intersectsBottom = bottomRect.intersect(touchPoint)
      if intersectsTop and intersectsBottom:
        return
      if intersectsTop:
        return (true, dirNorth)
      if intersectsBottom:
        return (true, dirSouth)