## wgrender scene3d example, in Nim: a port of wgrender's examples/scene3d.c.
##
## Retained shapes in a scene, drawn by the scene's draw. Click shapes to select them
## (the scene's pick). The selected shape turns white.

import std/math
import wgr

const Ring = 8

type App = object
  scene: Scene
  camera: Camera3d
  background: Color
  spinner: Shape3d
  selected: Shape3d
  ring: array[Ring, Shape3d]
  sphere: Shape3d

var g: App

proc onInit() =
  g.background = rgba(24, 26, 34, 255)
  g.camera = newCamera3d(Projection.Perspective)
  g.camera.setView(position = (16.0, 11.0, 16.0), target = (0.0, 1.0, 0.0))

  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)

  for i in 0 ..< Ring:
    let a = i.float * 6.2831853 / 8.0
    let cube = newShape3d()
    cube.setCube((1.5, 1.5, 1.5))
    cube.setTransform((cos(a) * 6.0, 0.75, sin(a) * 6.0), (0.0, a, 0.0), (1.0, 1.0, 1.0))
    cube.setColor(if i mod 2 == 1: ColorSkyblue else: ColorOrange)
    g.scene.add(cube)
    g.ring[i] = cube

  g.sphere = newShape3d()
  g.sphere.setSphere(1.5)
  g.sphere.setTransform((0.0, 2.5, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.sphere.setColor(ColorGold)
  g.scene.add(g.sphere)

  g.spinner = newShape3d()
  g.spinner.setCube((2.0, 2.0, 2.0))
  g.spinner.setColor(ColorLime)
  g.scene.add(g.spinner, 1)

  enableFps(12, 10, 16)

proc defaultColorFor(shape: Shape3d): Color =
  if shape == g.spinner:
    return ColorLime
  if shape == g.sphere:
    return ColorGold
  for i in 0 ..< Ring:
    if g.ring[i] == shape:
      return (if i mod 2 == 1: ColorSkyblue else: ColorOrange)
  ColorRaywhite

proc shapeFor(handle: Handle): Shape3d =
  ## which of the shapes a pick hit; none for none
  if handle == g.spinner: return g.spinner
  if handle == g.sphere: return g.sphere
  for cube in g.ring:
    if handle == cube: return cube
  Shape3d(0)

proc updateSelection(hit: Shape3d) =
  if hit == g.selected:
    return

  if not g.selected.isNone:
    g.selected.setColor(defaultColorFor(g.selected))

  g.selected = hit
  if not g.selected.isNone:
    g.selected.setColor(ColorRaywhite)

proc frame(dt, tickFraction: float) =
  let t = getTime()
  let mouse = getMouseState()

  g.camera.setView(position = (cos(t * 0.35) * 18.0, 11.0, sin(t * 0.35) * 18.0),
                   target = (0.0, 1.0, 0.0))

  g.spinner.setTransform((0.0, 5.0, 0.0), (t * 1.3, t * 0.9, 0.0), (1.0, 1.0, 1.0))

  if mouse.left == ButtonState.Pressed:
    let pick = g.scene.pick(mouse.x.float, mouse.y.float)
    updateSelection(if pick.hit: shapeFor(pick.handle) else: Shape3d(0))

  beginFrame()
  clearBackground(g.background)

  beginMode3d()
  drawGrid(24, 1.0, ColorDarkgray)
  endMode3d()

  g.scene.draw()

  drawText("wgrender scene pick (Nim)", 12, 36, 24, ColorRaywhite)
  drawText("click a shape to select it", 12, 70, 16, ColorLightgray)

  let status = if not g.selected.isNone: "selected handle: " & $g.selected else: "selected: none"
  drawText(status, 12, 94, 16, ColorLightgray)

  endFrame()

  when not defined(emscripten): # a web page has nothing to quit to
    if getKey(Key.Escape) == ButtonState.Pressed: requestQuit()

when isMainModule:
  initValues(900, 700, "scene3d (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
