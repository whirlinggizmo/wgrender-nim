## wgrender 3D example, in Nim: a port of wgrender's examples/hello3d.c.
##
## A camera orbits the origin, over depth-tested immediate 3D shapes (the grid, the
## axes, a cube and two spheres), with a 2D overlay on top.

import std/math
import wgr

var
  camera: Camera3d
  background: Color

proc onInit() =
  camera = newCamera3d(Projection.Perspective) # default fov: pi/4
  camera.setView(position = (14.0, 8.0, 14.0), target = (0.0, 1.0, 0.0))
  camera.setActive()
  background = rgba(28, 28, 38, 255)
  enableFps(12, 10, 16)

proc frame(dt, tickFraction: float) =
  # orbit the camera around the origin
  let t = getTime()
  camera.setView(position = (cos(t * 0.4) * 16, 9.0, sin(t * 0.4) * 16), target = (0.0, 1.0, 0.0))

  beginFrame()
  clearBackground(background)

  beginMode3d()
  drawGrid(20, 1.0, ColorDarkgray)
  # axes
  drawLine((0.0, 0.0, 0.0), (5.0, 0.0, 0.0), ColorRed)
  drawLine((0.0, 0.0, 0.0), (0.0, 5.0, 0.0), ColorGreen)
  drawLine((0.0, 0.0, 0.0), (0.0, 0.0, 5.0), ColorBlue)
  drawCube((0.0, 1.0, 0.0), (2.0, 2.0, 2.0), ColorSkyblue)
  drawCubeWires((0.0, 1.0, 0.0), (2.02, 2.02, 2.02), ColorDarkblue)
  drawSphere((5.0, 1.5, 0.0), 1.5, ColorGold)
  drawSphere((-5.0, 1.5, 0.0), 1.5, ColorMaroon)
  endMode3d()

  drawText("wgrender hello3d (Nim)", 12, 36, 24, ColorRaywhite)
  drawText("orbiting camera, depth-tested immediate shapes", 12, 70, 16, ColorLightgray)
  endFrame()

  # Escape quits on desktop; a web page has nothing to quit to.
  when not defined(emscripten):
    if isKeyPressed(Key.Escape):
      requestQuit()

when isMainModule:
  initValues(900, 700, "hello3d (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
