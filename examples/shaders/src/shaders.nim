## wgrender shaders example, in Nim: a port of wgrender's examples/shaders.c.
##
## Materials drawn by shaders of your own.
##   - left: toon shading (lights in flat bands, a rim light) on the animated
##     character: custom shaders work on skinned models too
##   - middle: a sphere dissolving and coming back through a noise texture, with a
##     glowing edge (time, a texture, discard)
##   - right: a sphere of water rippling in waves (a vertex hook moves the surface)
##     reflecting the scene's environment
##   - a logo sprite, in the world and in the screen's corner: one material outlines
##     it and pulses a flash (its shader reads the sprite's own texture)
## The shaders are the .glsl files in wgrender's examples/shaders, compiled for every
## backend by its tools/shaderpack.py into .wgrshader files in examples/assets/shaders
## (tools/gen_shaders.py --examples). They load through the asset system like any
## other file. A sun, a point light circling in front and an environment (a sunset,
## not shown as the background) light the scene. Keys: 1 sun, 2 point light, ESC quit.

import std/math
import wgr

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: "assets" beside the page, fetched on a cache miss then stored
  # in idbfs; relative, not "/assets", so the site works wherever it is hosted: at a
  # domain root (tools/serve.py mounts wgrender's examples/assets at /assets) and
  # equally under a path, as GitHub Pages serves this project at /wgrender-nim/.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "assets" else: "examples/assets"

  CharacterPath = "models/woman_casual/woman_casual.glb"
  NoisePath = "textures/noise.png"
  LogoPath = "sprites/logo/wg-logo-white-alpha.png"
  EnvironmentPath = "environments/venice_sunset_1k.hdr"
  FloorY = -0.3
  SphereY = FloorY + 0.5 # spheres 1 m across, resting on the floor
  CharacterBodySlot = 1

type ShaderKind = enum
  Toon, Dissolve, Wave, SpriteFx

const ShaderPaths: array[ShaderKind, string] = [
  "shaders/toon.wgrshader",
  "shaders/dissolve.wgrshader",
  "shaders/wave.wgrshader",
  "shaders/sprite_fx.wgrshader",
]

type App = object
  scene: Scene
  camera: Camera3d
  bg: Color
  character, dissolving, rippling: Model
  floor: Model
  dissolve: Material # its material gets the noise texture
  sun, lamp: Light
  lampMarker: Shape3d
  logo3d: Sprite3d # drawn by the sprite effects shader
  logo2d: Sprite2d
  time: float

var g: App

proc load(path: string; onReady: proc (path: string)) =
  let onFailed = proc (path: string) = logError("load failed: " & path)
  if not ensureAssetAsync(path).addTask(onReady, onFailed):
    onFailed(path)

proc loadShader(which: ShaderKind) =
  ## A shader: when it's loaded, make its material and give it to its model.
  load(ShaderPaths[which]) do (path: string):
    let shader = newShader(path)
    let material = newMaterial(shader)
    shader.release() # the material holds its own reference
    if material.isNone: return

    case which
    of Toon:
      material.setColor("color", rgba(255, 196, 120, 255))
      material.setFloat("bands", 3.0)
      material.setFloat("rim", 0.35)
      g.character.setMaterial(CharacterBodySlot, material)
    of Dissolve:
      material.setVec4("color", (0.55, 0.6, 0.7, 1.0)) # linear
      material.setVec3("edge_color", (4.0, 1.2, 0.2))
      material.setFloat("speed", 0.15)
      material.setDoubleSided(true) # the inside shows through the holes
      g.dissolving.setMaterial(0, material)
      g.dissolve = material # the model holds a reference; this one is released below
      load(NoisePath) do (path: string):
        let texture = newTexture(path)
        if not g.dissolve.isNone: g.dissolve.setTexture("noise_tex", texture)
        texture.release() # the material holds its own reference
    of Wave:
      material.setFloat("amplitude", 0.03)
      material.setFloat("frequency", 2.5)
      material.setFloat("wave_speed", 3.0)
      material.setVec4("low_color", (0.0, 0.03, 0.1, 1.0)) # deep water
      material.setVec4("high_color", (0.05, 0.3, 0.35, 1.0))
      material.setFloat("roughness", 0.05)
      material.setFloat("reflectivity", 0.35) # real water is 0.02: more, so it shows
      g.rippling.setMaterial(0, material)
    of SpriteFx: # one material, a 3D and a 2D sprite
      material.setVec4("outline_color", (1.0, 0.45, 0.1, 1.0))
      material.setFloat("outline_width", 2.5)
      material.setFloat("flash", 0.8)
      material.setFloat("pulse_speed", 5.0)
      g.logo3d.setMaterial(material)
      g.logo2d.setMaterial(material)
    material.release() # the models hold their own references

proc onInit() =
  setAssetHost(AssetBase)
  setAssetManifest(AssetManifestName)
  g.bg = rgba(20, 22, 28, 255)

  g.camera = newCamera3d(Projection.Perspective)
  g.camera.setView(position = (0.0, 1.2, 5.0), target = (0.0, 0.3, 0.0))
  g.scene = newScene()
  g.scene.setActiveCamera(g.camera)
  g.scene.setAmbient(ColorWhite, 0.15)

  g.sun = newLight(LightKind.Directional)
  g.sun.setDirection((-0.4, -0.7, -0.6))
  g.sun.setColor(rgba(255, 244, 228, 255))
  g.sun.setIntensity(1.5) # soft: the point light and the environment show too
  g.scene.add(g.sun)

  g.lamp = newLight(LightKind.Point)
  g.lamp.setColor(rgba(120, 190, 255, 255))
  g.lamp.setIntensity(9.0) # falls off with distance squared: ~2.3 at 2 m
  g.lamp.setRange(8.0)
  g.scene.add(g.lamp)
  g.lampMarker = newShape3d()
  g.lampMarker.setSphere(0.05)
  g.lampMarker.setColor(ColorSkyblue)
  g.scene.add(g.lampMarker)

  # generated meshes (newMesh<Shape>): a floor, so the models stand somewhere, and the
  # spheres; the water's finely divided, so its waves are smooth
  let plane = newMeshPlane(6.0, 6.0, 0)
  let sphere = newMeshSphere(0.5, 32, 64)
  let fineSphere = newMeshSphere(0.5, 96, 192)
  g.floor = newModel(plane)
  g.floor.setTransform((0.0, FloorY, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  let ground = newMaterial(MaterialShading.Pbr)
  ground.setVec4("base_color", (0.04, 0.04, 0.045, 1.0)) # dark: the lights show on it
  ground.setFloat("metallic", 0.0)
  ground.setFloat("roughness", 0.8)
  g.floor.setMaterial(-1, ground)
  ground.release() # the model holds its own reference
  g.scene.add(g.floor)

  g.character = newModel() # meshes attach when they load
  g.character.setTransform((-1.9, FloorY, 0.0), (0.0, 0.4, 0.0), (0.5, 0.5, 0.5)) # feet at its origin
  g.character.setAnimation(3)
  g.scene.add(g.character)
  g.dissolving = newModel(sphere)
  g.dissolving.setTransform((0.0, SphereY, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.scene.add(g.dissolving)
  g.rippling = newModel(fineSphere)
  g.rippling.setTransform((1.9, SphereY, 0.0), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.scene.add(g.rippling)
  plane.release() # the models hold their own references
  sphere.release()
  fineSphere.release()

  # the logo, in the world above the middle and in the screen's corner
  g.logo3d = newSprite3d()
  g.logo3d.setTransform((0.0, 1.55, -0.8), (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.logo3d.setSize(0.9)
  g.logo3d.setTint(rgba(90, 190, 255, 255)) # so the white flash shows
  g.scene.add(g.logo3d)
  g.logo2d = newSprite2d() # its texture set when it loads
  g.logo2d.setSize(96.0, 96.0)
  g.logo2d.setPivot(1.0, 1.0)
  g.logo2d.setTint(rgba(90, 190, 255, 255))
  load(LogoPath) do (path: string):
    let texture = newTexture(path)
    g.logo3d.setTexture(texture)
    g.logo2d.setTexture(texture)
    texture.release() # the sprites hold their own references

  for which in ShaderKind: loadShader(which)
  load(EnvironmentPath) do (path: string):
    let environment = newEnvironment(path)
    g.scene.setEnvironment(environment, 1.0, 0.0) # lighting only: the background stays dark
    environment.release() # the scene holds its own reference
  load(CharacterPath) do (path: string):
    let mesh = newMesh(path)
    g.character.setMesh(mesh)
    mesh.release()

proc frame(dt, tickFraction: float) =
  when not defined(emscripten): # a web page has nothing to quit to
    if isKeyPressed(Key.Escape): requestQuit()
  if isKeyPressed(Key.Digit1): g.sun.setEnabled(not g.sun.isEnabled)
  if isKeyPressed(Key.Digit2): g.lamp.setEnabled(not g.lamp.isEnabled)

  g.time += dt
  # circling in front of the models, facing the camera: always in view, and 1.8 m or
  # more from them (closer, it would wash them out)
  let lamp = (cos(g.time * 0.7) * 2.2, 0.8 + sin(g.time * 0.7) * 1.0, 1.8)
  g.lamp.setPosition(lamp)
  g.lampMarker.setTransform(lamp, (0.0, 0.0, 0.0), (1.0, 1.0, 1.0))
  g.lampMarker.setVisible(g.lamp.isEnabled)
  g.dissolving.setTransform((0.0, SphereY, 0.0), (0.0, g.time * 0.4, 0.0), (1.0, 1.0, 1.0))
  g.character.animate(dt)

  beginFrame()
  clearBackground(g.bg)
  g.scene.draw()
  let screen = getScreenSize()
  g.logo2d.setPosition(screen.x - 16.0, screen.y - 16.0) # bottom right
  g.logo2d.draw()
  drawText("wgrender custom shaders (Nim): toon, dissolve, water, sprite effects", 12, 12, 20,
           ColorRaywhite)
  drawText("1 sun, 2 point light, ESC quit", 12, 40, 16, ColorLightgray)
  endFrame()

when isMainModule:
  initValues(960, 540, "shaders (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
