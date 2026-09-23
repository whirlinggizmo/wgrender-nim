## wgrender simple example, in Nim — a port of wgrender's examples/simple.c (itself the
## reference scene shared with librl's C, Haxe and Nim "simple" examples).
##
## Scene: an animated model, a bobbing 3D sprite, looping music, two TTF fonts,
## a centered message that reports what the mouse is over (scene picking), and a
## debug overlay with timers, mouse state and the platform name.

import std/[math, strformat]
import wgr

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: the served origin (wgrender's tools/serve.py mounts
  # examples/assets at /assets), fetched on a cache miss then stored in idbfs.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "/assets" else: "examples/assets"

  DebugFontPath = "fonts/JetBrainsMono/JetBrainsMono-Regular.ttf"
  KomikaFontPath = "fonts/Komika/KOMIKAH_.ttf"
  ModelPath = "models/gumshoe/gumshoe.glb"
  SpritePath = "sprites/logo/wg-logo-bw-alpha.png"
  BgmPath = "music/ethernight_club.mp3"

  ScreenWidth = 1024
  ScreenHeight = 1280
  DebugFontSize = 18
  KomikaFontSize = 24

  SpriteYOffset = 3.0
  BobSpeed = 1.0
  BobHeight = 1.5

type
  App = object
    elapsed: float
    countdownTimer: float
    debugFont: Font
    greyAlpha: Color
    komikaFont: Font
    sprite: Sprite3d
    model: Model
    bgm: Sound
    camera: Camera3d
    scene: Scene
    backgroundColor: Color
    message: string
    platformText: string

var g: App

# --- assets: the path is local and ready; create the resource, then the object ---

proc load(path: string; onReady: AssetCallback) =
  let onFailed = proc (path: string) = logError("failed to import asset: " & path)
  if not assetAddTask(assetEnsureAsync(path), onReady, onFailed):
    onFailed(path)

proc loadAssets() =
  load(BgmPath) do (path: string):
    let audio = audioCreate(path)
    g.bgm = soundCreate(audio)
    audioRelease(audio) # the sound holds its own reference
    soundSetLoop(g.bgm, true)
    soundPlay(g.bgm)

  load(ModelPath) do (path: string):
    let mesh = meshCreate(path)
    g.model = modelCreate(mesh)
    meshRelease(mesh) # the model holds its own reference
    modelSetAnimation(g.model, 1)
    modelSetAnimationSpeed(g.model, 1.0)
    modelSetAnimationLoop(g.model, true)
    modelSetPosition(g.model, (0.0, 0.0, 0.0))
    modelSetTint(g.model, ColorRaywhite)
    sceneAdd(g.scene, g.model)

  load(SpritePath) do (path: string):
    let texture = textureCreate(path)
    g.sprite = sprite3dCreate(texture)
    textureRelease(texture) # the sprite holds its own reference
    sprite3dSetFacing(g.sprite, SpriteFacing.Free) # librl's default: oriented by its rotation
    sprite3dSetPosition(g.sprite, (0.0, SpriteYOffset, 0.0))
    sprite3dSetTint(g.sprite, ColorRaywhite)
    sceneAdd(g.scene, g.sprite)

  # Fonts are sized per draw call in wgrender, so one font handle serves any size.
  load(DebugFontPath) do (path: string):
    g.debugFont = fontCreate(path)
  load(KomikaFontPath) do (path: string):
    g.komikaFont = fontCreate(path)

# --- lifecycle ---

proc onInit() =
  assetSetHost(AssetBase)
  loggerSetLevel(LogLevel.Warn)
  setTargetFps(60)

  g.countdownTimer = 30.0
  g.message = "Hello from wgrender simple (Nim)!"
  g.platformText = "Platform: " & getPlatform()

  g.camera = camera3dCreate(Projection.Perspective) # default fov: pi/4 (45 degrees)
  camera3dSetView(g.camera, position = (12.0, 12.0, 12.0), target = (0.0, 1.0, 0.0))
  g.scene = sceneCreate()
  sceneSetActiveCamera(g.scene, g.camera)

  # same lighting as librl's c-simple: a directional light plus ambient 0.25
  let sun = lightCreate(LightKind.Directional)
  lightSetDirection(sun, (-0.6, -1.0, -0.5))
  lightSetIntensity(sun, 3.0)
  sceneAdd(g.scene, sun)
  sceneSetAmbient(g.scene, ColorWhite, 0.25)
  g.backgroundColor = colorRgba(245, 245, 245, 255)
  g.greyAlpha = colorRgba(0, 0, 0, 128)

  loadAssets()

proc update(dt: float) =
  g.elapsed += dt
  g.countdownTimer -= dt

  if not g.model.isNone:
    modelAnimate(g.model, dt)
  if not g.sprite.isNone:
    let y = sin(g.elapsed * BobSpeed) * BobHeight + SpriteYOffset
    sprite3dSetPosition(g.sprite, (0.0, y, 0.0))

proc updatePickMessage(mouse: MouseState) =
  let pick = scenePick(g.scene, mouse.x.float, mouse.y.float)
  let what =
    if not pick.hit: ""
    elif pick.handle == g.model: "Model"
    elif pick.handle == g.sprite: "Sprite"
    else: ""
  if what.len == 0:
    g.message = "Nothing picked!"
    return
  g.message = &"{what} pick: Mouse position (mouse.x:{mouse.x}, mouse.y:{mouse.y}) " &
              &"pick result y: {pick.pointWorld.y:.6f}"

# Draw with the TTF font once it's loaded, the built-in font until then.
proc drawText(font: Font; text: string; x, y: float; size: int; color: Color) =
  if not font.isNone:
    textDrawEx(font, text, x, y, size.float, color)
  else:
    textDraw(text, x.int, y.int, size, color)

proc drawCenteredMessage() =
  let screen = windowGetScreenSize()
  let size =
    if not g.komikaFont.isNone: textMeasureEx(g.komikaFont, g.message, KomikaFontSize)
    else: (textMeasure(g.message, KomikaFontSize).float, KomikaFontSize.float)
  drawText(g.komikaFont, g.message, (screen.x - size.x) / 2, (screen.y - size.y) / 2,
           KomikaFontSize, ColorBlue)

proc drawOverlay(mouse: MouseState) =
  drawText(g.debugFont, &"Remaining: {g.countdownTimer:.2f}", 10, 36, DebugFontSize, ColorBlack)
  drawText(g.debugFont, &"Elapsed: {g.elapsed:.2f}", 10, 56, DebugFontSize, ColorBlack)
  drawText(g.debugFont,
           &"Mouse: ({mouse.x}, {mouse.y}) w:{mouse.wheel:.1f} " &
           &"b:[{mouse.left}, {mouse.right}, {mouse.middle}]",
           10, 76, DebugFontSize, ColorBlack)
  drawText(g.debugFont, g.platformText, 10, 96, DebugFontSize, ColorBlack)

  textDrawFpsEx(g.debugFont, 10, 10, DebugFontSize, g.greyAlpha)

proc frame(dt, tickFraction: float) =
  let mouse = inputGetMouseState()

  # Escape quits on desktop; a web page has nothing to quit to.
  when not defined(emscripten):
    if isKeyPressed(Key.Escape):
      requestQuit()

  update(dt)
  updatePickMessage(mouse)

  renderBegin()
  renderClearBackground(g.backgroundColor)
  sceneDraw(g.scene)
  drawCenteredMessage()
  drawOverlay(mouse)
  renderEnd()

when isMainModule:
  initValues(ScreenWidth, ScreenHeight, "simple (wgrender, Nim)",
             {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
