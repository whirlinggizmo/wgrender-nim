## wgrender font example, in Nim: a port of wgrender's examples/font.c.
##
## TrueType text via fontstash, loaded async. Loads two fonts (JetBrains Mono, Komika)
## with ensureAssetAsync, then draws scalable text including a measured, centered line.
##
##   D    switch the default font (drawText without a font) between the built-in font
##        (JetBrains Mono, ASCII) and Komika
##   ESC  quit

import wgr

const
  # Where assets load from. Desktop: config.nims points this at wgrender's
  # examples/assets. Web: "assets" beside the page, fetched on a cache miss then stored
  # in idbfs; relative, not "/assets", so the site works wherever it is hosted: at a
  # domain root (tools/serve.py mounts wgrender's examples/assets at /assets) and
  # equally under a path, as GitHub Pages serves this project at /wgrender-nim/.
  AssetBase {.strdefine: "wgrAssetBase".} =
    when defined(emscripten): "assets" else: "examples/assets"

  JetbrainsPath = "fonts/JetBrainsMono/JetBrainsMono-Regular.ttf"
  KomikaPath = "fonts/Komika/KOMIKAH_.ttf"

var
  background: Color
  mono: Font
  komika: Font

proc onFailed(path: string) = logError("font load failed: " & path)

proc onInit() =
  setAssetHost(AssetBase)
  background = rgba(248, 248, 250, 255)
  if not ensureAssetAsync(JetbrainsPath).addTask(proc (path: string) = mono = newFont(path), onFailed):
    onFailed(JetbrainsPath)
  if not ensureAssetAsync(KomikaPath).addTask(proc (path: string) = komika = newFont(path), onFailed):
    onFailed(KomikaPath)

proc frame(dt, tickFraction: float) =
  let screen = getScreenSize()

  beginFrame()
  clearBackground(background)

  # centered title (Komika), measured
  let title = "wgrender + fontstash (Nim)"
  if not komika.isNone:
    let size = komika.measureText(title, 56)
    komika.drawText(title, (screen.x - size.x) * 0.5, 90, 56, ColorDarkblue)

  # a few sizes of mono text
  if not mono.isNone:
    mono.drawText("The quick brown fox jumps over the lazy dog.", 40, 200, 28, ColorBlack)
    mono.drawText("scalable, anti-aliased TrueType glyphs", 40, 250, 20, ColorDarkgray)
    mono.drawText("0123456789  !@#$%^&*()  +-*/=", 40, 290, 24, ColorMaroon)
  else:
    drawText("loading fonts...", 40, 200, 20, ColorGray)

  # the default font: built in (JetBrains Mono), or Komika after D
  let keys = getKeyboardState()
  if keys.isPressed(Key.D) and not komika.isNone:
    setDefaultFont(if getDefaultFont().isNone: komika else: default(Font))
  drawText(if getDefaultFont().isNone: "[D] default font: built in   {a|b} ~ \\ ^_`"
           else: "[D] default font: Komika   {a|b} ~ \\ ^_`",
           40, 360, 16, ColorDarkgreen)

  # FPS in the default font
  drawFps(12, 12)

  endFrame()

  when not defined(emscripten): # a web page has nothing to quit to
    if keys.isPressed(Key.Escape): requestQuit()

when isMainModule:
  initValues(900, 500, "font (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
