## wgr_input.h, wrapped.

import ./types, ./internal/convert, ./raw

type
  KeyboardState* = object
    ## every key at once, plus this frame's pressed keys and chars; for one key,
    ## `getKey` / `isKeyPressed` are simpler
    c: CKeyboardState

proc getMouseState*(): MouseState =
  let m = wgr_input_get_mouse_state()
  MouseState(x: m.x.int, y: m.y.int, wheel: m.wheel.float, wheelX: m.wheel_x.float,
             left: ButtonState(m.left), right: ButtonState(m.right), middle: ButtonState(m.middle),
             buttons: [ButtonState(m.buttons[0]), ButtonState(m.buttons[1]), ButtonState(m.buttons[2])],
             dx: m.dx.int, dy: m.dy.int)

proc getKey*(key: Key): ButtonState = ButtonState(wgr_input_get_key(ord(key).cint))

proc isKeyPressed*(key: Key): bool =
  ## went down this frame
  getKey(key) == ButtonState.Pressed

proc isKeyDown*(key: Key): bool =
  ## held, including the frame it went down
  getKey(key) in {ButtonState.Pressed, ButtonState.Down}

proc isKeyReleased*(key: Key): bool =
  ## went up this frame
  getKey(key) == ButtonState.Released

proc isGamepadConnected*(pad: int): bool = wgr_input_is_gamepad_connected(pad.cint)

proc getGamepadName*(pad: int): string =
  ## "" when none is connected there
  $wgr_input_get_gamepad_name(pad.cint)

proc getGamepadButton*(pad: int; button: GamepadButton): ButtonState =
  ButtonState(wgr_input_get_gamepad_button(pad.cint, ord(button).cint))

proc isGamepadButtonPressed*(pad: int; button: GamepadButton): bool =
  ## went down this frame
  getGamepadButton(pad, button) == ButtonState.Pressed

proc isGamepadButtonDown*(pad: int; button: GamepadButton): bool =
  ## held, including the frame it went down
  getGamepadButton(pad, button) in {ButtonState.Pressed, ButtonState.Down}

proc isGamepadButtonReleased*(pad: int; button: GamepadButton): bool =
  ## went up this frame
  getGamepadButton(pad, button) == ButtonState.Released

proc getGamepadAxis*(pad: int; axis: GamepadAxis): float =
  ## sticks -1 .. 1 (y down), triggers 0 .. 1, after the dead zone
  wgr_input_get_gamepad_axis(pad.cint, ord(axis).cint).float

proc setGamepadDeadzone*(radius: float): bool {.discardable.} =
  ## how far a stick moves before it reads other than 0
  wgr_input_set_gamepad_deadzone(radius.cfloat)

proc getKeyboardState*(): KeyboardState = KeyboardState(c: wgr_input_get_keyboard_state())

proc `[]`*(state: KeyboardState; key: Key): ButtonState = ButtonState(state.c.keys[ord(key)])

proc isPressed*(state: KeyboardState; key: Key): bool =
  ## went down this frame
  state[key] == ButtonState.Pressed

proc isDown*(state: KeyboardState; key: Key): bool =
  ## held, including the frame it went down
  state[key] in {ButtonState.Pressed, ButtonState.Down}

proc isReleased*(state: KeyboardState; key: Key): bool =
  ## went up this frame
  state[key] == ButtonState.Released

proc getMousePosition*(): Vec2 = wgr_input_get_mouse_position().toNim
proc getMouseDelta*(): Vec2 = wgr_input_get_mouse_delta().toNim ## moved this frame
proc getMouseWheel*(): float = wgr_input_get_mouse_wheel().float
proc getMouseWheelX*(): float = wgr_input_get_mouse_wheel_x().float
proc getMouseButton*(button: MouseButton): ButtonState =
  ButtonState(wgr_input_get_mouse_button(ord(button).cint))
proc captureCursor*() = wgr_input_capture_cursor() ## hidden and held: only its movement counts
proc releaseCursor*() = wgr_input_release_cursor()

proc getTouchCount*(): int = wgr_input_get_touch_count().int
proc getTouch*(index: int): Touch =
  let t = wgr_input_get_touch(index.cint)
  Touch(id: t.id.int, x: t.x.float, y: t.y.float, dx: t.dx.float, dy: t.dy.float, state: ButtonState(t.state))
proc getTouchGesture*(): TouchGesture =
  let g = wgr_input_get_touch_gesture()
  TouchGesture(active: g.active, x: g.x.float, y: g.y.float, dx: g.dx.float, dy: g.dy.float,
               scale: g.scale.float, rotation: g.rotation.float)

# Captured: the pointer or keyboard is taken by the UI this frame, so the game ignores it.
proc isPointerCaptured*(): bool = wgr_input_is_pointer_captured()
proc setPointerCaptured*(captured: bool) = wgr_input_set_pointer_captured(captured)
proc isKeyboardCaptured*(): bool = wgr_input_is_keyboard_captured()
proc setKeyboardCaptured*(captured: bool) = wgr_input_set_keyboard_captured(captured)
