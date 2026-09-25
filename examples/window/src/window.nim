## wgrender window example, in Nim: a port of wgrender's examples/window.c.
##
##   arrows      move the window 50 pixels
##   = / -       grow / shrink the window by 10%
##   F           toggle fullscreen
##   M           move to the next monitor
##   H           hide the window for two seconds
##   Escape      quit
##
## On a Wayland desktop (Linux, through XWayland) the compositor places windows:
## moving and changing monitor report "not supported here". On the web the canvas is
## the window: resizing works, moving and other monitors don't.

import std/[math, strformat]
import wgr

var
  background: Color
  message = "press a key"
  hiddenFor = 0.0 # seconds left hidden

proc report(what: string; ok: bool) =
  message = what & ": " & (if ok: "done" else: "not supported here")

proc onInit() =
  background = rgba(24, 28, 38, 255)

proc frame(dt, tickFraction: float) =
  let keys = getKeyboardState()
  let size = getScreenSize()
  let position = getWindowPosition()

  when not defined(emscripten): # a web page has nothing to quit to
    if keys.isPressed(Key.Escape): requestQuit()
  if keys.isPressed(Key.Left): report("move", setWindowPosition(position.x.int - 50, position.y.int))
  if keys.isPressed(Key.Right): report("move", setWindowPosition(position.x.int + 50, position.y.int))
  if keys.isPressed(Key.Up): report("move", setWindowPosition(position.x.int, position.y.int - 50))
  if keys.isPressed(Key.Down): report("move", setWindowPosition(position.x.int, position.y.int + 50))
  if keys.isPressed(Key.Equal):
    report("grow", setWindowSize(int(size.x * 1.1), int(size.y * 1.1)))
  if keys.isPressed(Key.Minus):
    report("shrink", setWindowSize(int(size.x / 1.1), int(size.y / 1.1)))
  if keys.isPressed(Key.F): # a request: isFullscreen answers on a later frame
    message = "fullscreen: " & (if requestFullscreen(not isFullscreen()): "requested" else: "not supported here")
  if keys.isPressed(Key.H) and setWindowVisible(false):
    hiddenFor = 2.0
    report("hide for 2 s", true)
  if hiddenFor > 0:
    hiddenFor -= dt
    if hiddenFor <= 0: # it keeps running while hidden
      report("show", setWindowVisible(true))
  if keys.isPressed(Key.M):
    report("monitor", setMonitor((getMonitor() + 1) mod getMonitorCount()))

  beginFrame()
  clearBackground(background)
  var y = 12
  drawText(if hasFullscreen(): # ask before offering the key
             "wgrender window (Nim)   arrows: move   =/-: size   F: fullscreen   M: next monitor   H: hide"
           else:
             "wgrender window (Nim)   arrows: move   =/-: size   (no fullscreen here)   M: next monitor   H: hide",
           12, y, 16, ColorRaywhite)
  y += 32
  drawText(&"window: {int(round(size.x))} x {int(round(size.y))} at ({int(round(position.x))}, {int(round(position.y))})   " &
           &"fullscreen: {(if isFullscreen(): \"yes\" else: \"no\")}   focused: {(if isWindowFocused(): \"yes\" else: \"no\")}",
           12, y, 16, ColorLightgray)
  y += 24
  drawText(message, 12, y, 16, ColorGold)
  y += 32
  for m in 0 ..< getMonitorCount():
    let mSize = getMonitorSize(m)
    let mPosition = getMonitorPosition(m)
    let marker = if m == getMonitor(): ">" else: " "
    drawText(&"{marker} monitor {m} \"{getMonitorName(m)}\": {int(round(mSize.x))} x {int(round(mSize.y))} " &
             &"at ({int(round(mPosition.x))}, {int(round(mPosition.y))})", 12, y, 16, ColorLightgray)
    y += 22
  endFrame()

when isMainModule:
  initValues(900, 400, "window (wgrender, Nim)", {WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
