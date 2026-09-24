## How the binding's calls are written, checked at compile time: the calls are
## compiled, never run, so this needs no window.
##
##   cd tests && nim c -r tcalls.nim

import wgr

let
  m = Model(0)
  s = Sprite3d(0)
  v: Vec3 = (1.0, 2.0, 3.0)
  h = Handle(0)

# a call on a handle: method call syntax, the plain call, and qualified by the module
doAssert compiles(m.setPosition(v))
doAssert compiles(setPosition(m, v))
doAssert compiles(wgr.setPosition(m, v))
doAssert compiles(m.setPosition(1, 2, 3)) # the x, y, z overload takes int literals
doAssert compiles(s.setTransform(v, v, v))
doAssert compiles(s.getPosition())

# a wrong handle kind is refused, whichever way it is written
doAssert not compiles(s.setAnimation(1))
doAssert not compiles(setAnimation(s, 1))
doAssert not compiles(setPosition(h, v))
doAssert not compiles(newSprite3d(Mesh(0)))
doAssert not compiles(newScene().add(Texture(0)))

# constructors are new<Kind>, and return that kind; with the wrong arguments they
# don't compile (a name of system's, like create, would have quietly matched it)
doAssert newModel(Mesh(0)) is Model
doAssert newTexture("x") is Texture
doAssert newScene() is Scene
doAssert newCamera3d() is Camera3d
doAssert wgr.newTexture("x") is Texture
doAssert not compiles(newTexture())
doAssert not compiles(newTexture(1))

# calls without a handle are plain procs, qualified or not
doAssert compiles(beginFrame())
doAssert compiles(wgr.endFrame())
doAssert compiles(drawText("hi", 0, 0, 16, ColorBlack))               # the built-in font
doAssert compiles(Font(0).drawText("hi", 0.0, 0.0, 16.0, ColorBlack)) # a font of its own
doAssert measureText("hi", 16) is int
doAssert Font(0).measureText("hi", 16.0) is Vec2
doAssert compiles(ensureAssetAsync("x").addTask(proc (p: string) = discard))
doAssert compiles(setTargetFps(60))
doAssert compiles(logWarn("careful"))
doAssert rgba(1, 2, 3, 4) is Color

# bool results are discardable: a bare call, with no `discard`
proc discardable() {.used.} =
  m.setPosition(v)
  setPosition(m, v)
  m.setPosition(1, 2, 3)
  m.setTint(ColorWhite)
  s.setFacing(SpriteFacing.Free)
doAssert compiles(discardable())

echo "tcalls: ok"
