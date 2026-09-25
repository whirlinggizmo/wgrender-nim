## wgrender tick example, in Nim: a port of wgrender's examples/tick.c.
##
## A fixed-rate simulation (tick) against rendering (frame). A deliberately slow 10 Hz
## tick moves two squares at the same speed: the top one is drawn at its latest tick
## position, so it visibly steps; the bottom one is drawn between its last two tick
## positions using tickFraction, so it moves smoothly at any frame rate. Press Space:
## the presses counted inside the tick and inside the frame always match, because
## each press is seen by exactly one tick.

import std/strformat
import wgr

const
  ScreenWidth = 800
  ScreenHeight = 450
  TickHz = 10
  Square = 40.0
  Left = 40.0
  Right = ScreenWidth - 80.0
  Speed = 240.0 # pixels per second

var g: tuple[prevX, x: float; ticks, tickPresses, framePresses: int; background: Color]

proc tick(dt: float) =
  g.prevX = g.x
  g.x += Speed * dt
  if g.x > Right:
    g.x = Left
    g.prevX = g.x # don't interpolate across the wrap
  inc g.ticks
  if isKeyPressed(Key.Space):
    inc g.tickPresses

proc frame(dt, tickFraction: float) =
  let keys = getKeyboardState()
  if keys.isPressed(Key.Space):
    inc g.framePresses
  when not defined(emscripten): # a web page has nothing to quit to
    if keys.isPressed(Key.Escape):
      requestQuit()

  beginFrame()
  clearBackground(g.background)
  drawText("wgrender tick (Nim): 10 Hz simulation, rendered every frame", 20, 20, 20, ColorRaywhite)
  drawText(&"frame dt {dt:.4f} s   tickFraction {tickFraction:.2f}   ticks {g.ticks}", 20, 50, 16, ColorLightgray)
  drawText(&"Space presses: tick {g.tickPresses}, frame {g.framePresses}", 20, 74, 16, ColorLightgray)

  drawText("raw tick position", 20, 130, 16, ColorGray)
  drawRectangle(g.x.int.float, 155, Square, Square, ColorOrange)

  drawText("interpolated with tickFraction", 20, 250, 16, ColorGray)
  let smoothX = g.prevX + (g.x - g.prevX) * tickFraction
  drawRectangle(smoothX.int.float, 275, Square, Square, ColorSkyblue)

  drawFps(20, ScreenHeight - 30)
  endFrame()

proc onInit() =
  g.background = rgba(24, 26, 34, 255)
  g.x = Left
  g.prevX = Left

when isMainModule:
  initValues(ScreenWidth, ScreenHeight, "tick (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setTick(tick, TickHz)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
