# Package

version       = "1.0.0"
author        = "Dominik Picheta"
description   = "A 2D JavaScript game akin to Nokia's Snake."
license       = "MIT"

# Dependencies

requires "nim >= 0.16.0", "gamelight", "websocket", "jswebsockets"

task server, "Compile server":
  exec "nim c snake/server"

task debug, "Compile debug client":
  exec "nim js --out:public/snake.js -d:local snake.nim"

task release, "Compile release client":
  exec "nim js --out:public/snake.js snake.nim"