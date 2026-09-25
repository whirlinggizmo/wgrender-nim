## wgrender gamepad example, in Nim: a port of wgrender's examples/gamepad.c.
##
## Every connected pad, live. Up to four side by side: the name, both sticks (the dot
## is where the stick is, after the dead zone; the ring is its reach), the triggers as
## bars, and the buttons laid out like an Xbox-style pad, lit while held and flashed on
## the frame they're pressed. South on a pad cycles the dead zone. In a browser, press a
## button on the pad first: pages only see gamepads after that.

import std/[strformat, strutils]
import wgr

const
  Deadzones = [0.15, 0.0, 0.3]
  Reach = 34.0         # a stick's ring
  TriggerHeight = 60.0

var
  deadzone = 0
  idle, outline: Color

proc buttonColor(pad: int; button: GamepadButton): Color =
  ## white the frame it goes down, gold while held, dark otherwise
  case getGamepadButton(pad, button)
  of ButtonState.Pressed: ColorWhite
  of ButtonState.Down: ColorGold
  else: idle

proc drawButton(pad: int; button: GamepadButton; x, y, r: float) =
  drawCircle((x, y), r, buttonColor(pad, button))

proc drawStick(pad: int; xAxis, yAxis: GamepadAxis; click: GamepadButton; cx, cy: float) =
  drawCircleLines((cx, cy), Reach, outline)
  if getGamepadButton(pad, click) != ButtonState.Up:
    drawCircle((cx, cy), Reach, idle)
  drawCircle((cx + getGamepadAxis(pad, xAxis) * Reach, cy + getGamepadAxis(pad, yAxis) * Reach),
             9.0, ColorSkyblue)

proc drawTrigger(pad: int; axis: GamepadAxis; x, y: float) =
  let value = getGamepadAxis(pad, axis)
  drawRectangleLines(x, y, 16, TriggerHeight, outline)
  drawRectangle(x, y + TriggerHeight * (1 - value), 16, TriggerHeight * value, ColorOrange)

proc signed(v: float): string = (if v >= 0: "+" else: "") & v.formatFloat(ffDecimal, 2)

proc drawPad(pad: int; x, y: float) =
  drawText(&"pad {pad}", x.int, y.int, 20, ColorRaywhite)
  if not isGamepadConnected(pad):
    drawText("not connected", x.int, y.int + 26, 16, ColorGray)
    return
  let name = getGamepadName(pad)
  drawText(name[0 ..< min(name.len, 40)], x.int, y.int + 26, 14, ColorLightgray)

  # shoulders and triggers
  drawTrigger(pad, GamepadAxis.LeftTrigger, x + 10, y + 56)
  drawTrigger(pad, GamepadAxis.RightTrigger, x + 274, y + 56)
  drawRectangle(x + 34, y + 60, 60, 14, buttonColor(pad, GamepadButton.LeftBumper))
  drawRectangle(x + 206, y + 60, 60, 14, buttonColor(pad, GamepadButton.RightBumper))

  # sticks, d-pad, face buttons, middle buttons
  drawStick(pad, GamepadAxis.LeftX, GamepadAxis.LeftY, GamepadButton.LeftStick, x + 70, y + 130)
  drawStick(pad, GamepadAxis.RightX, GamepadAxis.RightY, GamepadButton.RightStick, x + 190, y + 210)
  drawRectangle(x + 102, y + 180, 18, 18, buttonColor(pad, GamepadButton.DpadUp))
  drawRectangle(x + 102, y + 220, 18, 18, buttonColor(pad, GamepadButton.DpadDown))
  drawRectangle(x + 82, y + 200, 18, 18, buttonColor(pad, GamepadButton.DpadLeft))
  drawRectangle(x + 122, y + 200, 18, 18, buttonColor(pad, GamepadButton.DpadRight))
  drawButton(pad, GamepadButton.North, x + 240, y + 106, 12)
  drawButton(pad, GamepadButton.South, x + 240, y + 154, 12)
  drawButton(pad, GamepadButton.West, x + 216, y + 130, 12)
  drawButton(pad, GamepadButton.East, x + 264, y + 130, 12)
  drawButton(pad, GamepadButton.Back, x + 126, y + 130, 8)
  drawButton(pad, GamepadButton.Guide, x + 150, y + 110, 10)
  drawButton(pad, GamepadButton.Start, x + 174, y + 130, 8)

  drawText(&"L {signed(getGamepadAxis(pad, GamepadAxis.LeftX))} " &
           &"{signed(getGamepadAxis(pad, GamepadAxis.LeftY))}  " &
           &"R {signed(getGamepadAxis(pad, GamepadAxis.RightX))} " &
           &"{signed(getGamepadAxis(pad, GamepadAxis.RightY))}",
           x.int, y.int + 262, 14, ColorLightgray)

proc onInit() =
  idle = rgba(60, 66, 80, 255)
  outline = rgba(90, 98, 118, 255)

proc frame(dt, tickFraction: float) =
  for pad in 0 ..< MaxGamepads:
    if isGamepadButtonPressed(pad, GamepadButton.South):
      deadzone = (deadzone + 1) mod Deadzones.len
      setGamepadDeadzone(Deadzones[deadzone])

  beginFrame()
  clearBackground(rgba(20, 22, 30, 255))
  drawText("wgrender gamepads (Nim)", 12, 36, 24, ColorRaywhite)
  drawText(&"dead zone {Deadzones[deadzone]:.2f} (South changes it)   web: press a pad button first",
           12, 70, 16, ColorLightgray)
  for pad in 0 ..< MaxGamepads:
    drawPad(pad, 20.0 + float(pad mod 2) * 320, 110.0 + float(pad div 2) * 300)
  endFrame()

  # Escape quits on desktop; a web page has nothing to quit to.
  when not defined(emscripten):
    if isKeyPressed(Key.Escape):
      requestQuit()

when isMainModule:
  initValues(680, 720, "gamepad (wgrender, Nim)", {WindowFlag.Msaa4x, WindowFlag.Resizable})
  setInit(onInit)
  setFrame(frame)
  let status = run()
  # On the web wgr_run returns at once and the browser drives the frames, so don't
  # exit() here: that would tear the program down.
  when not defined(emscripten):
    quit status
