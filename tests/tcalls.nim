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

# emitters: the shared calls take either kind; a position or direction takes the kind's
# vector, a Vec3 in the world or a Vec2 in pixels
let e3 = Emitter3d(0)
let e2 = Emitter2d(0)
doAssert newEmitter3d(Texture(0)) is Emitter3d
doAssert newEmitter2d(Texture(0)) is Emitter2d
doAssert compiles(e3.setRate(30.0))
doAssert compiles(e2.setRate(30.0))
doAssert compiles(e3.setVelocity(v, spread = 0.2))
doAssert compiles(e2.setVelocity((0.0, -420.0)))
doAssert not compiles(e2.setVelocity(v))                   # a 2D one takes a Vec2
doAssert not compiles(e3.setSpawnCircle(1.0))              # a 3D one spawns in a sphere
doAssert compiles(e3.setAlphaMode(AlphaMode.Blend))
doAssert e3.getCount() is int
doAssert compiles(newScene().add(e3))
doAssert compiles(newScene().add(e2, 1))
doAssert not compiles(e3.setAnimation(1))

# only Nim types reach a consumer: a handle is not a number, and state is an enum
doAssert not compiles(h + 1)
doAssert not compiles(Handle(0) == 0)
doAssert newScene().pick(0.0, 0.0).handle is Handle
doAssert getMouseState().left is ButtonState
doAssert compiles(getMouseState().left == ButtonState.Pressed)

# gamepads: buttons and axes are enums, a button's state a ButtonState
doAssert getGamepadButton(0, GamepadButton.South) is ButtonState
doAssert getGamepadAxis(0, GamepadAxis.LeftX) is float
doAssert getGamepadName(0) is string
doAssert compiles(isGamepadButtonPressed(0, GamepadButton.Start))
doAssert not compiles(getGamepadButton(0, 0))                    # a number is not a button
doAssert not compiles(getGamepadAxis(0, GamepadButton.South))    # nor a button an axis
doAssert MaxGamepads == 4

# bool results are discardable: a bare call, with no `discard`
proc discardable() {.used.} =
  m.setPosition(v)
  setPosition(m, v)
  m.setPosition(1, 2, 3)
  m.setTint(ColorWhite)
  s.setFacing(SpriteFacing.Free)
  e3.setRate(30.0)
  e2.burst(300)
  setGamepadDeadzone(0.2)
doAssert compiles(discardable())

echo "tcalls: ok"
