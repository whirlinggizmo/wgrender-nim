## wgrender hello example, in Nim: a port of wgrender's examples/hello.c.
##
## A window, a clear, 2D shapes, text and input. wgrender owns the loop: configure
## with initValues, register a frame callback, then run.

import wgr

proc frame(dt, tickFraction: float) =
  let mouse = getMouseState()

  beginFrame()
  clearBackground(ColorRaywhite)

  # filled + outlined rectangles
  drawRectangle(40, 40, 200, 120, ColorSkyblue)
  drawRectangleLines(40, 40, 200, 120, ColorDarkblue)

  # line + triangle + circles
  drawLine((40.0, 200.0), (240.0, 320.0), ColorRed)
  drawTriangle((320.0, 60.0), (280.0, 180.0), (360.0, 180.0), ColorGold)
  drawCircle((440.0, 120.0), 60, ColorPurple)
  drawCircleLines((440.0, 120.0), 60, ColorBlack)

  # a marker that follows the mouse
  drawCircle((mouse.x.float, mouse.y.float), 8, ColorMaroon)

  drawText("wgrender hello (Nim)", 40, 360, 32, ColorDarkgray)
  drawText("press ESC to quit", 40, 410, 16, ColorGray)
  drawFps(40, 12)
  endFrame()

  # Escape quits on desktop; a web page has nothing to quit to.
  when not defined(emscripten):
    if isKeyPressed(Key.Escape):
      requestQuit()

when isMainModule:
  initValues(800, 600, "hello (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
