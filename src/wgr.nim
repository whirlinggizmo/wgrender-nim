## wgrender for Nim: the C API (wgr/raw) wrapped in stock Nim types.
##
## Nothing exported here names a C type: a consumer never writes a cstring, a cint, a
## cast or a WGR_ constant. tools/coverage.py --check (CI) fails on any exported proc,
## type, constant or field that does; C stays in wgr/raw.
##
## - strings, ints and floats instead of cstring / cint / cfloat
## - Nim enums and a `set` of window flags instead of C constants (button states too)
## - handles as distinct types, the untyped `Handle` included: not a number
## - vectors as tuples, mouse and pick state as Nim objects
## - closures for callbacks, called through cdecl trampolines
## - a distinct type per handle kind (Model, Texture, Font, ...), so passing the
##   wrong kind is a compile error; the zero value is "none" (`isNone`)
## - the calls read as Nim, not C: on a handle, the call is its action, on the
##   handle by method call syntax (`wgr_model_set_position(m, ...)` is
##   `m.setPosition(v)`), overloaded on the handle kinds; a constructor is
##   `new<Kind>` (`wgr_model_create` is `newModel(mesh)`); anything else is its
##   action as a plain proc (`wgr_render_begin_frame` is `beginFrame()`), with its
##   section as a noun only where the action alone would be ambiguous
##   (`drawText`, `measureText`, `setAssetHost`, `setLogLevel`). `wgr.` in front
##   qualifies any of them: `wgr.newTexture(path)`
## - `bool` results are discardable
##
## `wgr/raw` has the C API as is, for anything not wrapped here.

import wgr/raw

type
  Handle* = distinct uint32 ## an untyped wgrender handle (a pick result's hit); 0 is none
  Color* = uint32           ## packed 0xRRGGBBAA, a value

  # Resources: loaded, reference counted, shared
  Audio* = distinct Handle
  Mesh* = distinct Handle
  Texture* = distinct Handle
  Font* = distinct Handle
  Material* = distinct Handle ## how a model or sprite's surface is shaded
  Shader* = distinct Handle   ## a custom material shader (.wgrshader)
  # Objects: placed or heard, each with its own state
  Sound* = distinct Handle
  Model* = distinct Handle
  Sprite3d* = distinct Handle
  Camera3d* = distinct Handle
  Light* = distinct Handle
  Scene* = distinct Handle
  Emitter3d* = distinct Handle ## particles in the 3D world
  Emitter2d* = distinct Handle ## particles on the screen, in pixels
  Sprite2d* = distinct Handle  ## a texture on the screen, in pixels
  Shape3d* = distinct Handle   ## a cube, sphere, rectangle, circle or line in the world
  AssetTask* = distinct Handle

  AnyHandle* = Audio | Mesh | Texture | Font | Material | Shader | Sound | Model | Sprite3d | Sprite2d |
               Shape3d | Camera3d | Light | Scene | Emitter3d | Emitter2d | AssetTask
  SceneMember* = Model | Sprite3d | Sprite2d | Shape3d | Light | Emitter3d | Emitter2d
    ## what a scene's add takes
  Emitter* = Emitter3d | Emitter2d


  Vec2* = tuple[x, y: float]
  Vec3* = tuple[x, y, z: float]
  Vec4* = tuple[x, y, z, w: float]
  Rect* = tuple[x, y, width, height: float] ## a region: of a texture in its pixels, or of the screen

  MouseState* = object
    x*, y*: int
    wheel*, wheelX*: float ## scroll this frame: about one unit per wheel notch
    left*, right*, middle*: ButtonState
    buttons*: array[3, ButtonState] ## left, right, middle, by index
    dx*, dy*: int

  PickResult* = object
    hit*: bool
    handle*: Handle
    distance*: float ## world-space distance from the ray origin to the hit
    pointLocal*, pointWorld*: Vec3
    normalLocal*, normalWorld*: Vec3

  WindowFlag* {.pure.} = enum
    ## Bit positions of WGR_WINDOW_FLAG_*
    Fullscreen = 1, Resizable = 2, Undecorated = 3, Transparent = 4,
    Msaa4x = 5, VsyncOff = 6, Hidden = 7, LowDpi = 13

  LogLevel* {.pure.} = enum
    Trace, Debug, Info, Warn, Error, Fatal

  AssetFlag* {.pure.} = enum
    ForceFetch ## re-download even if cached
    FileOnly   ## only make the file local; don't load the resource it names

  Projection* {.pure.} = enum
    Perspective, Orthographic

  LightKind* {.pure.} = enum
    Directional, Point, Spot

  AlphaMode* {.pure.} = enum
    ## how a sprite, material or emitter uses alpha
    Opaque ## alpha ignored
    Mask   ## fully opaque or fully transparent, split at a cutoff; depth written
    Blend  ## alpha blended, back to front
    Add    ## added to what's behind (glows, sparks); not sorted, no depth write

  MaterialShading* {.pure.} = enum
    Pbr    ## glTF metallic-roughness, lit by scene lights
    Unlit  ## base color x texture x tint; ignores lights
    Custom ## a custom shader (newMaterial(shader)); not for newMaterial(shading)

  TextureWrap* {.pure.} = enum
    Repeat ## tile
    Clamp  ## stretch the edge texels
    Mirror ## tile, flipping every other copy

  TextureFilter* {.pure.} = enum
    Linear  ## smooth; blends mipmap levels when minified
    Nearest ## sharp texels (pixel art)

  SpriteFacing* {.pure.} = enum
    Camera       ## parallel to the view plane
    CameraFixedY ## turns about world Y to face the camera, stays upright
    YUp          ## flat in the XZ plane, normal +Y
    Free         ## its own rotation: the local XY plane, facing +Z

  ButtonState* {.pure.} = enum
    Up       ## not held
    Pressed  ## went down this frame
    Down     ## held
    Released ## went up this frame

  Key* {.pure.} = enum
    ## wgrender's key codes (WGR_KEY_*, wgr_keys.h); generated, and checked against the
    ## header at C compile time (the _Static_asserts below)
    Space = 32, Apostrophe = 39, Comma = 44, Minus = 45, Period = 46, Slash = 47,
    Digit0 = 48, Digit1 = 49, Digit2 = 50, Digit3 = 51, Digit4 = 52, Digit5 = 53,
    Digit6 = 54, Digit7 = 55, Digit8 = 56, Digit9 = 57, Semicolon = 59, Equal = 61,
    A = 65, B = 66, C = 67, D = 68, E = 69, F = 70, G = 71, H = 72, I = 73, J = 74,
    K = 75, L = 76, M = 77, N = 78, O = 79, P = 80, Q = 81, R = 82, S = 83, T = 84,
    U = 85, V = 86, W = 87, X = 88, Y = 89, Z = 90, LeftBracket = 91, Backslash = 92,
    RightBracket = 93, GraveAccent = 96, Escape = 256, Enter = 257, Tab = 258,
    Backspace = 259, Insert = 260, Delete = 261, Right = 262, Left = 263, Down = 264,
    Up = 265, PageUp = 266, PageDown = 267, Home = 268, End = 269, CapsLock = 280,
    F1 = 290, F2 = 291, F3 = 292, F4 = 293, F5 = 294, F6 = 295, F7 = 296, F8 = 297,
    F9 = 298, F10 = 299, F11 = 300, F12 = 301, LeftShift = 340, LeftControl = 341,
    LeftAlt = 342, LeftSuper = 343, RightShift = 344, RightControl = 345, RightAlt = 346,
    RightSuper = 347

  GamepadButton* {.pure.} = enum
    ## a pad's buttons, named by position (South is A on Xbox, Cross on PlayStation)
    South, East, West, North, LeftBumper, RightBumper, LeftTrigger, RightTrigger,
    Back   ## view / select / share / minus
    Start  ## menu / options / plus
    Guide  ## the logo button
    LeftStick, RightStick, DpadUp, DpadDown, DpadLeft, DpadRight

  GamepadAxis* {.pure.} = enum
    ## sticks -1 .. 1 with y down, like the screen; triggers 0 .. 1
    LeftX, LeftY, RightX, RightY, LeftTrigger, RightTrigger

  KeyboardState* = object
    ## every key at once, plus this frame's pressed keys and chars; for one key,
    ## `getKey` / `isKeyPressed` are simpler
    c: CKeyboardState

  AssetCallback* = proc (path: string) {.closure.}
  InitCallback* = proc () {.closure.}
  FrameCallback* = proc (dt, tickFraction: float) {.closure.}
  TickCallback* = proc (dt: float) {.closure.}

const
  MaxGamepads* = 4 ## pads at once, each keeping its slot (0 .. 3) while connected
  ColorLightgray* = WGR_COLOR_LIGHTGRAY
  ColorGray* = WGR_COLOR_GRAY
  ColorDarkgray* = WGR_COLOR_DARKGRAY
  ColorYellow* = WGR_COLOR_YELLOW
  ColorGold* = WGR_COLOR_GOLD
  ColorOrange* = WGR_COLOR_ORANGE
  ColorPink* = WGR_COLOR_PINK
  ColorRed* = WGR_COLOR_RED
  ColorMaroon* = WGR_COLOR_MAROON
  ColorGreen* = WGR_COLOR_GREEN
  ColorLime* = WGR_COLOR_LIME
  ColorDarkgreen* = WGR_COLOR_DARKGREEN
  ColorSkyblue* = WGR_COLOR_SKYBLUE
  ColorBlue* = WGR_COLOR_BLUE
  ColorDarkblue* = WGR_COLOR_DARKBLUE
  ColorPurple* = WGR_COLOR_PURPLE
  ColorViolet* = WGR_COLOR_VIOLET
  ColorDarkpurple* = WGR_COLOR_DARKPURPLE
  ColorBeige* = WGR_COLOR_BEIGE
  ColorBrown* = WGR_COLOR_BROWN
  ColorDarkbrown* = WGR_COLOR_DARKBROWN
  ColorWhite* = WGR_COLOR_WHITE
  ColorBlack* = WGR_COLOR_BLACK
  ColorBlank* = WGR_COLOR_BLANK
  ColorMagenta* = WGR_COLOR_MAGENTA
  ColorRaywhite* = WGR_COLOR_RAYWHITE

# The C side's handle, for raw's calls; not exported, so a handle stays a handle.
template raw(h: Handle): WgrHandle = WgrHandle(uint32(h))
template raw(h: AnyHandle): WgrHandle = WgrHandle(uint32(Handle(h)))

proc `==`*(a, b: Handle): bool {.borrow.}
proc `$`*(h: Handle): string {.borrow.}
proc isNone*(h: Handle): bool = uint32(h) == 0 ## no handle: nothing hit, or none made
proc `==`*[T: AnyHandle](a, b: T): bool = a.raw == b.raw
proc `==`*(a: Handle; b: AnyHandle): bool = a.raw == b.raw
proc `==`*(a: AnyHandle; b: Handle): bool = a.raw == b.raw
proc `$`*(h: AnyHandle): string = $h.raw
proc isNone*(h: AnyHandle): bool = h.raw == 0 ## not created (yet), or creation failed

# The checks include wgr.h themselves: otherwise they depend on some other call in the
# same C file having pulled it in, which a program that only type-checks never does.
# Each is an array typedef whose size goes negative when a key's value is wrong, not a
# _Static_assert: Nim's own C is compiled without /std:c11 by MSVC, which then has no
# _Static_assert. A mismatch fails to compile, naming the key in the type.
{.emit: """
#include "wgr.h"
typedef char wgr_nim_Key_Space_is_out_of_date_with_wgr_keys_h[(WGR_KEY_SPACE == 32) ? 1 : -1];
typedef char wgr_nim_Key_Apostrophe_is_out_of_date_with_wgr_keys_h[(WGR_KEY_APOSTROPHE == 39) ? 1 : -1];
typedef char wgr_nim_Key_Comma_is_out_of_date_with_wgr_keys_h[(WGR_KEY_COMMA == 44) ? 1 : -1];
typedef char wgr_nim_Key_Minus_is_out_of_date_with_wgr_keys_h[(WGR_KEY_MINUS == 45) ? 1 : -1];
typedef char wgr_nim_Key_Period_is_out_of_date_with_wgr_keys_h[(WGR_KEY_PERIOD == 46) ? 1 : -1];
typedef char wgr_nim_Key_Slash_is_out_of_date_with_wgr_keys_h[(WGR_KEY_SLASH == 47) ? 1 : -1];
typedef char wgr_nim_Key_Digit0_is_out_of_date_with_wgr_keys_h[(WGR_KEY_0 == 48) ? 1 : -1];
typedef char wgr_nim_Key_Digit1_is_out_of_date_with_wgr_keys_h[(WGR_KEY_1 == 49) ? 1 : -1];
typedef char wgr_nim_Key_Digit2_is_out_of_date_with_wgr_keys_h[(WGR_KEY_2 == 50) ? 1 : -1];
typedef char wgr_nim_Key_Digit3_is_out_of_date_with_wgr_keys_h[(WGR_KEY_3 == 51) ? 1 : -1];
typedef char wgr_nim_Key_Digit4_is_out_of_date_with_wgr_keys_h[(WGR_KEY_4 == 52) ? 1 : -1];
typedef char wgr_nim_Key_Digit5_is_out_of_date_with_wgr_keys_h[(WGR_KEY_5 == 53) ? 1 : -1];
typedef char wgr_nim_Key_Digit6_is_out_of_date_with_wgr_keys_h[(WGR_KEY_6 == 54) ? 1 : -1];
typedef char wgr_nim_Key_Digit7_is_out_of_date_with_wgr_keys_h[(WGR_KEY_7 == 55) ? 1 : -1];
typedef char wgr_nim_Key_Digit8_is_out_of_date_with_wgr_keys_h[(WGR_KEY_8 == 56) ? 1 : -1];
typedef char wgr_nim_Key_Digit9_is_out_of_date_with_wgr_keys_h[(WGR_KEY_9 == 57) ? 1 : -1];
typedef char wgr_nim_Key_Semicolon_is_out_of_date_with_wgr_keys_h[(WGR_KEY_SEMICOLON == 59) ? 1 : -1];
typedef char wgr_nim_Key_Equal_is_out_of_date_with_wgr_keys_h[(WGR_KEY_EQUAL == 61) ? 1 : -1];
typedef char wgr_nim_Key_A_is_out_of_date_with_wgr_keys_h[(WGR_KEY_A == 65) ? 1 : -1];
typedef char wgr_nim_Key_B_is_out_of_date_with_wgr_keys_h[(WGR_KEY_B == 66) ? 1 : -1];
typedef char wgr_nim_Key_C_is_out_of_date_with_wgr_keys_h[(WGR_KEY_C == 67) ? 1 : -1];
typedef char wgr_nim_Key_D_is_out_of_date_with_wgr_keys_h[(WGR_KEY_D == 68) ? 1 : -1];
typedef char wgr_nim_Key_E_is_out_of_date_with_wgr_keys_h[(WGR_KEY_E == 69) ? 1 : -1];
typedef char wgr_nim_Key_F_is_out_of_date_with_wgr_keys_h[(WGR_KEY_F == 70) ? 1 : -1];
typedef char wgr_nim_Key_G_is_out_of_date_with_wgr_keys_h[(WGR_KEY_G == 71) ? 1 : -1];
typedef char wgr_nim_Key_H_is_out_of_date_with_wgr_keys_h[(WGR_KEY_H == 72) ? 1 : -1];
typedef char wgr_nim_Key_I_is_out_of_date_with_wgr_keys_h[(WGR_KEY_I == 73) ? 1 : -1];
typedef char wgr_nim_Key_J_is_out_of_date_with_wgr_keys_h[(WGR_KEY_J == 74) ? 1 : -1];
typedef char wgr_nim_Key_K_is_out_of_date_with_wgr_keys_h[(WGR_KEY_K == 75) ? 1 : -1];
typedef char wgr_nim_Key_L_is_out_of_date_with_wgr_keys_h[(WGR_KEY_L == 76) ? 1 : -1];
typedef char wgr_nim_Key_M_is_out_of_date_with_wgr_keys_h[(WGR_KEY_M == 77) ? 1 : -1];
typedef char wgr_nim_Key_N_is_out_of_date_with_wgr_keys_h[(WGR_KEY_N == 78) ? 1 : -1];
typedef char wgr_nim_Key_O_is_out_of_date_with_wgr_keys_h[(WGR_KEY_O == 79) ? 1 : -1];
typedef char wgr_nim_Key_P_is_out_of_date_with_wgr_keys_h[(WGR_KEY_P == 80) ? 1 : -1];
typedef char wgr_nim_Key_Q_is_out_of_date_with_wgr_keys_h[(WGR_KEY_Q == 81) ? 1 : -1];
typedef char wgr_nim_Key_R_is_out_of_date_with_wgr_keys_h[(WGR_KEY_R == 82) ? 1 : -1];
typedef char wgr_nim_Key_S_is_out_of_date_with_wgr_keys_h[(WGR_KEY_S == 83) ? 1 : -1];
typedef char wgr_nim_Key_T_is_out_of_date_with_wgr_keys_h[(WGR_KEY_T == 84) ? 1 : -1];
typedef char wgr_nim_Key_U_is_out_of_date_with_wgr_keys_h[(WGR_KEY_U == 85) ? 1 : -1];
typedef char wgr_nim_Key_V_is_out_of_date_with_wgr_keys_h[(WGR_KEY_V == 86) ? 1 : -1];
typedef char wgr_nim_Key_W_is_out_of_date_with_wgr_keys_h[(WGR_KEY_W == 87) ? 1 : -1];
typedef char wgr_nim_Key_X_is_out_of_date_with_wgr_keys_h[(WGR_KEY_X == 88) ? 1 : -1];
typedef char wgr_nim_Key_Y_is_out_of_date_with_wgr_keys_h[(WGR_KEY_Y == 89) ? 1 : -1];
typedef char wgr_nim_Key_Z_is_out_of_date_with_wgr_keys_h[(WGR_KEY_Z == 90) ? 1 : -1];
typedef char wgr_nim_Key_LeftBracket_is_out_of_date_with_wgr_keys_h[(WGR_KEY_LEFT_BRACKET == 91) ? 1 : -1];
typedef char wgr_nim_Key_Backslash_is_out_of_date_with_wgr_keys_h[(WGR_KEY_BACKSLASH == 92) ? 1 : -1];
typedef char wgr_nim_Key_RightBracket_is_out_of_date_with_wgr_keys_h[(WGR_KEY_RIGHT_BRACKET == 93) ? 1 : -1];
typedef char wgr_nim_Key_GraveAccent_is_out_of_date_with_wgr_keys_h[(WGR_KEY_GRAVE_ACCENT == 96) ? 1 : -1];
typedef char wgr_nim_Key_Escape_is_out_of_date_with_wgr_keys_h[(WGR_KEY_ESCAPE == 256) ? 1 : -1];
typedef char wgr_nim_Key_Enter_is_out_of_date_with_wgr_keys_h[(WGR_KEY_ENTER == 257) ? 1 : -1];
typedef char wgr_nim_Key_Tab_is_out_of_date_with_wgr_keys_h[(WGR_KEY_TAB == 258) ? 1 : -1];
typedef char wgr_nim_Key_Backspace_is_out_of_date_with_wgr_keys_h[(WGR_KEY_BACKSPACE == 259) ? 1 : -1];
typedef char wgr_nim_Key_Insert_is_out_of_date_with_wgr_keys_h[(WGR_KEY_INSERT == 260) ? 1 : -1];
typedef char wgr_nim_Key_Delete_is_out_of_date_with_wgr_keys_h[(WGR_KEY_DELETE == 261) ? 1 : -1];
typedef char wgr_nim_Key_Right_is_out_of_date_with_wgr_keys_h[(WGR_KEY_RIGHT == 262) ? 1 : -1];
typedef char wgr_nim_Key_Left_is_out_of_date_with_wgr_keys_h[(WGR_KEY_LEFT == 263) ? 1 : -1];
typedef char wgr_nim_Key_Down_is_out_of_date_with_wgr_keys_h[(WGR_KEY_DOWN == 264) ? 1 : -1];
typedef char wgr_nim_Key_Up_is_out_of_date_with_wgr_keys_h[(WGR_KEY_UP == 265) ? 1 : -1];
typedef char wgr_nim_Key_PageUp_is_out_of_date_with_wgr_keys_h[(WGR_KEY_PAGE_UP == 266) ? 1 : -1];
typedef char wgr_nim_Key_PageDown_is_out_of_date_with_wgr_keys_h[(WGR_KEY_PAGE_DOWN == 267) ? 1 : -1];
typedef char wgr_nim_Key_Home_is_out_of_date_with_wgr_keys_h[(WGR_KEY_HOME == 268) ? 1 : -1];
typedef char wgr_nim_Key_End_is_out_of_date_with_wgr_keys_h[(WGR_KEY_END == 269) ? 1 : -1];
typedef char wgr_nim_Key_CapsLock_is_out_of_date_with_wgr_keys_h[(WGR_KEY_CAPS_LOCK == 280) ? 1 : -1];
typedef char wgr_nim_Key_F1_is_out_of_date_with_wgr_keys_h[(WGR_KEY_F1 == 290) ? 1 : -1];
typedef char wgr_nim_Key_F2_is_out_of_date_with_wgr_keys_h[(WGR_KEY_F2 == 291) ? 1 : -1];
typedef char wgr_nim_Key_F3_is_out_of_date_with_wgr_keys_h[(WGR_KEY_F3 == 292) ? 1 : -1];
typedef char wgr_nim_Key_F4_is_out_of_date_with_wgr_keys_h[(WGR_KEY_F4 == 293) ? 1 : -1];
typedef char wgr_nim_Key_F5_is_out_of_date_with_wgr_keys_h[(WGR_KEY_F5 == 294) ? 1 : -1];
typedef char wgr_nim_Key_F6_is_out_of_date_with_wgr_keys_h[(WGR_KEY_F6 == 295) ? 1 : -1];
typedef char wgr_nim_Key_F7_is_out_of_date_with_wgr_keys_h[(WGR_KEY_F7 == 296) ? 1 : -1];
typedef char wgr_nim_Key_F8_is_out_of_date_with_wgr_keys_h[(WGR_KEY_F8 == 297) ? 1 : -1];
typedef char wgr_nim_Key_F9_is_out_of_date_with_wgr_keys_h[(WGR_KEY_F9 == 298) ? 1 : -1];
typedef char wgr_nim_Key_F10_is_out_of_date_with_wgr_keys_h[(WGR_KEY_F10 == 299) ? 1 : -1];
typedef char wgr_nim_Key_F11_is_out_of_date_with_wgr_keys_h[(WGR_KEY_F11 == 300) ? 1 : -1];
typedef char wgr_nim_Key_F12_is_out_of_date_with_wgr_keys_h[(WGR_KEY_F12 == 301) ? 1 : -1];
typedef char wgr_nim_Key_LeftShift_is_out_of_date_with_wgr_keys_h[(WGR_KEY_LEFT_SHIFT == 340) ? 1 : -1];
typedef char wgr_nim_Key_LeftControl_is_out_of_date_with_wgr_keys_h[(WGR_KEY_LEFT_CONTROL == 341) ? 1 : -1];
typedef char wgr_nim_Key_LeftAlt_is_out_of_date_with_wgr_keys_h[(WGR_KEY_LEFT_ALT == 342) ? 1 : -1];
typedef char wgr_nim_Key_LeftSuper_is_out_of_date_with_wgr_keys_h[(WGR_KEY_LEFT_SUPER == 343) ? 1 : -1];
typedef char wgr_nim_Key_RightShift_is_out_of_date_with_wgr_keys_h[(WGR_KEY_RIGHT_SHIFT == 344) ? 1 : -1];
typedef char wgr_nim_Key_RightControl_is_out_of_date_with_wgr_keys_h[(WGR_KEY_RIGHT_CONTROL == 345) ? 1 : -1];
typedef char wgr_nim_Key_RightAlt_is_out_of_date_with_wgr_keys_h[(WGR_KEY_RIGHT_ALT == 346) ? 1 : -1];
typedef char wgr_nim_Key_RightSuper_is_out_of_date_with_wgr_keys_h[(WGR_KEY_RIGHT_SUPER == 347) ? 1 : -1];
typedef char wgr_nim_GamepadButton_South_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_SOUTH == 0) ? 1 : -1];
typedef char wgr_nim_GamepadButton_East_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_EAST == 1) ? 1 : -1];
typedef char wgr_nim_GamepadButton_West_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_WEST == 2) ? 1 : -1];
typedef char wgr_nim_GamepadButton_North_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_NORTH == 3) ? 1 : -1];
typedef char wgr_nim_GamepadButton_LeftBumper_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_LEFT_BUMPER == 4) ? 1 : -1];
typedef char wgr_nim_GamepadButton_RightBumper_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_RIGHT_BUMPER == 5) ? 1 : -1];
typedef char wgr_nim_GamepadButton_LeftTrigger_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_LEFT_TRIGGER == 6) ? 1 : -1];
typedef char wgr_nim_GamepadButton_RightTrigger_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_RIGHT_TRIGGER == 7) ? 1 : -1];
typedef char wgr_nim_GamepadButton_Back_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_BACK == 8) ? 1 : -1];
typedef char wgr_nim_GamepadButton_Start_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_START == 9) ? 1 : -1];
typedef char wgr_nim_GamepadButton_Guide_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_GUIDE == 10) ? 1 : -1];
typedef char wgr_nim_GamepadButton_LeftStick_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_LEFT_STICK == 11) ? 1 : -1];
typedef char wgr_nim_GamepadButton_RightStick_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_RIGHT_STICK == 12) ? 1 : -1];
typedef char wgr_nim_GamepadButton_DpadUp_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_DPAD_UP == 13) ? 1 : -1];
typedef char wgr_nim_GamepadButton_DpadDown_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_DPAD_DOWN == 14) ? 1 : -1];
typedef char wgr_nim_GamepadButton_DpadLeft_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_DPAD_LEFT == 15) ? 1 : -1];
typedef char wgr_nim_GamepadButton_DpadRight_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_BUTTON_DPAD_RIGHT == 16) ? 1 : -1];
typedef char wgr_nim_GamepadAxis_LeftX_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_AXIS_LEFT_X == 0) ? 1 : -1];
typedef char wgr_nim_GamepadAxis_LeftY_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_AXIS_LEFT_Y == 1) ? 1 : -1];
typedef char wgr_nim_GamepadAxis_RightX_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_AXIS_RIGHT_X == 2) ? 1 : -1];
typedef char wgr_nim_GamepadAxis_RightY_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_AXIS_RIGHT_Y == 3) ? 1 : -1];
typedef char wgr_nim_GamepadAxis_LeftTrigger_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_AXIS_LEFT_TRIGGER == 4) ? 1 : -1];
typedef char wgr_nim_GamepadAxis_RightTrigger_is_out_of_date_with_wgr_input_h[(WGR_GAMEPAD_AXIS_RIGHT_TRIGGER == 5) ? 1 : -1];
typedef char wgr_nim_MaxGamepads_is_out_of_date_with_wgr_input_h[(WGR_INPUT_MAX_GAMEPADS == 4) ? 1 : -1];
""".}

proc toNim(v: CVec2): Vec2 = (v.x.float, v.y.float)
proc toNim(v: CVec3): Vec3 = (v.x.float, v.y.float, v.z.float)

# --- lifecycle ---

var
  initCallback: InitCallback
  frameCallback: FrameCallback

proc initTrampoline(user: pointer) {.cdecl.} =
  if initCallback != nil: initCallback()

proc frameTrampoline(dt, tickFraction: cfloat; user: pointer) {.cdecl.} =
  if frameCallback != nil: frameCallback(dt.float, tickFraction.float)

proc initValues*(width, height: int; title: string; flags: set[WindowFlag] = {}): int {.discardable.} =
  var bits = 0'u32
  for f in flags: bits = bits or (1'u32 shl ord(f))
  wgr_init_values(width.cint, height.cint, title.cstring, bits).int

proc setInit*(cb: InitCallback) =
  initCallback = cb
  wgr_set_init(initTrampoline, nil)

proc setFrame*(cb: FrameCallback) =
  frameCallback = cb
  wgr_set_frame(frameTrampoline, nil)

var tickCallback: TickCallback

proc tickTrampoline(dt: cfloat; user: pointer) {.cdecl.} =
  if tickCallback != nil: tickCallback(dt.float)

proc setTick*(cb: TickCallback; hz: int) =
  ## a fixed-rate simulation step, `hz` times a second of real time, apart from the
  ## frames; the frame's tickFraction says how far it is between the last two ticks
  tickCallback = cb
  wgr_set_tick(tickTrampoline, nil, hz.cint)

proc getTime*(): float = wgr_get_time().float ## seconds since the program started

proc run*(): int {.discardable.} = wgr_run().int
proc requestQuit*() = wgr_request_quit() ## close the window / end the loop
proc getPlatform*(): string = $wgr_get_platform()
proc setTargetFps*(fps: int) = wgr_set_target_fps(fps.cint)

# --- logging ---
# `log` in front, as std/logging has debug, info, warn and error of its own

proc setLogLevel*(level: LogLevel) = wgr_logger_set_level(ord(level).cint)
proc logMessage*(level: LogLevel; msg: string) =
  wgr_logger_message(ord(level).cint, "%s", msg.cstring)

proc logTrace*(msg: string) = logMessage(LogLevel.Trace, msg)
proc logDebug*(msg: string) = logMessage(LogLevel.Debug, msg)
proc logInfo*(msg: string) = logMessage(LogLevel.Info, msg)
proc logWarn*(msg: string) = logMessage(LogLevel.Warn, msg)
proc logError*(msg: string) = logMessage(LogLevel.Error, msg)
proc logFatal*(msg: string) = logMessage(LogLevel.Fatal, msg)

# --- assets ---

type AssetCallbacks = ref object
  onSuccess, onFailure: AssetCallback

# wgrender fires exactly one of a task's callbacks, then frees the task, so each
# trampoline releases the closures it was handed.
proc finish(user: pointer; path: WgrConstCstring; success: bool) =
  let task = cast[AssetCallbacks](user)
  let cb = if success: task.onSuccess else: task.onFailure
  GC_unref(task)
  if cb != nil: cb($cstring(path))

proc assetSuccessTrampoline(path: WgrConstCstring; user: pointer) {.cdecl.} =
  finish(user, path, true)

proc assetFailureTrampoline(path: WgrConstCstring; user: pointer) {.cdecl.} =
  finish(user, path, false)

proc setAssetHost*(host: string) = wgr_asset_set_host(host.cstring)

proc ensureAssetAsync*(path: string; fetchUrl = ""; flags: set[AssetFlag] = {}): AssetTask =
  ## A task to attach callbacks to (task.addTask); none on failure.
  var bits = 0'u32
  for f in flags: bits = bits or (1'u32 shl ord(f))
  AssetTask(wgr_asset_ensure_async(path.cstring,
                                  (if fetchUrl.len > 0: fetchUrl.cstring else: nil), bits))

proc addTask*(task: AssetTask; onSuccess: AssetCallback;
              onFailure: AssetCallback = nil): bool {.discardable.} =
  ## Callbacks run on the main thread during a later frame. False (and no callback)
  ## if the task is invalid or the queue is full.
  let t = AssetCallbacks(onSuccess: onSuccess, onFailure: onFailure)
  GC_ref(t)
  result = wgr_asset_add_task(task.raw, assetSuccessTrampoline, assetFailureTrampoline,
                             cast[pointer](t)) == WGR_ASSET_ADD_TASK_OK
  if not result:
    GC_unref(t)

# --- colors ---

proc rgba*(r, g, b, a: int): Color = wgr_color_rgba(r.cint, g.cint, b.cint, a.cint)

# --- audio / sound ---

proc newAudio*(path: string): Audio = Audio(wgr_audio_create(path.cstring))
proc release*(audio: Audio) = wgr_audio_release(audio.raw)
proc newSound*(audio: Audio): Sound = Sound(wgr_sound_create(audio.raw))
proc setLoop*(sound: Sound; loop: bool): bool {.discardable.} = wgr_sound_set_loop(sound.raw, loop)
proc play*(sound: Sound): bool {.discardable.} = wgr_sound_play(sound.raw)

# --- mesh / model ---

proc newMesh*(path: string): Mesh = Mesh(wgr_mesh_create(path.cstring))
proc release*(mesh: Mesh) = wgr_mesh_release(mesh.raw)
proc newModel*(mesh: Mesh): Model = Model(wgr_model_create(mesh.raw))
proc newModel*(): Model = Model(wgr_model_create(0)) ## its mesh set later (setMesh)
proc setAnimation*(model: Model; index: int): bool {.discardable.} =
  wgr_model_set_animation(model.raw, index.cint)
proc setAnimationSpeed*(model: Model; speed: float): bool {.discardable.} =
  wgr_model_set_animation_speed(model.raw, speed.cfloat)
proc setAnimationLoop*(model: Model; loop: bool): bool {.discardable.} =
  wgr_model_set_animation_loop(model.raw, loop)
proc setTransform*(model: Model; position, rotation, scale: Vec3): bool {.discardable.} =
  ## position, rotation (radians) and scale in one call: the cheapest way to move it every frame
  wgr_model_set_transform(model.raw, position.x, position.y, position.z,
                         rotation.x, rotation.y, rotation.z, scale.x, scale.y, scale.z)
proc setPosition*(model: Model; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are
  wgr_model_set_position(model.raw, value.x, value.y, value.z)
proc setPosition*(model: Model; x, y, z: float): bool {.discardable.} =
  wgr_model_set_position(model.raw, x, y, z)
proc setRotation*(model: Model; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are (radians)
  wgr_model_set_rotation(model.raw, value.x, value.y, value.z)
proc setRotation*(model: Model; x, y, z: float): bool {.discardable.} =
  wgr_model_set_rotation(model.raw, x, y, z)
proc setScale*(model: Model; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are
  wgr_model_set_scale(model.raw, value.x, value.y, value.z)
proc setScale*(model: Model; x, y, z: float): bool {.discardable.} =
  wgr_model_set_scale(model.raw, x, y, z)
proc getPosition*(model: Model): Vec3 = wgr_model_get_position(model.raw).toNim
proc getRotation*(model: Model): Vec3 = wgr_model_get_rotation(model.raw).toNim
proc getScale*(model: Model): Vec3 = wgr_model_get_scale(model.raw).toNim
proc setTint*(model: Model; color: Color): bool {.discardable.} = wgr_model_set_tint(model.raw, color)
proc animate*(model: Model; dt: float): bool {.discardable.} = wgr_model_animate(model.raw, dt.cfloat)

# The built-in meshes: new<Kind><Variant>, as newTextureTarget. Centered on the origin,
# to be placed and scaled by the model; one material slot (white, not metallic,
# roughness 0.5), for setMaterial. A size at or below 0 gives none; counts are clamped
# to their ranges. The defaults are wgrender-hx's.

proc newMeshPlane*(width, length: float; subdivisions = 0): Mesh =
  ## flat in XZ facing +Y; `subdivisions` 0..256 adds that many cells each way
  Mesh(wgr_mesh_create_plane(width.cfloat, length.cfloat, subdivisions.cint))
proc newMeshCube*(width, height, length: float): Mesh =
  ## each face its own vertices, so the edges stay sharp; textured 0..1 per face
  Mesh(wgr_mesh_create_cube(width.cfloat, height.cfloat, length.cfloat))
proc newMeshSphere*(radius: float; rings = 16; segments = 32): Mesh =
  ## `rings` 2..256 pole to pole, `segments` 3..512 around
  Mesh(wgr_mesh_create_sphere(radius.cfloat, rings.cint, segments.cint))
proc newMeshCylinder*(radius, height: float; segments = 32): Mesh =
  ## capped; `segments` 3..512 around
  Mesh(wgr_mesh_create_cylinder(radius.cfloat, height.cfloat, segments.cint))
proc newMeshCone*(radius, height: float; segments = 32): Mesh =
  ## tip up, capped base
  Mesh(wgr_mesh_create_cone(radius.cfloat, height.cfloat, segments.cint))
proc newMeshCapsule*(radius, height: float; rings = 8; segments = 32): Mesh =
  ## `height` is end to end, at least twice `radius`; less than that gives a sphere
  Mesh(wgr_mesh_create_capsule(radius.cfloat, height.cfloat, rings.cint, segments.cint))
proc newMeshTorus*(radius, thickness: float; rings = 16; segments = 32): Mesh =
  ## around y: `radius` reaches the middle of the tube, `thickness` is its radius
  Mesh(wgr_mesh_create_torus(radius.cfloat, thickness.cfloat, rings.cint, segments.cint))
proc getMaterialCount*(mesh: Mesh): int = wgr_mesh_get_material_count(mesh.raw).int
proc getMaterial*(mesh: Mesh; slot: int): Material = Material(wgr_mesh_get_material(mesh.raw, slot.cint))

proc setMesh*(model: Model; mesh: Mesh): bool {.discardable.} = wgr_model_set_mesh(model.raw, mesh.raw)
proc setMaterial*(model: Model; slot: int; material: Material): bool {.discardable.} =
  ## this model's own material for a slot of its mesh, over the mesh's
  wgr_model_set_material(model.raw, slot.cint, material.raw)
proc getMaterial*(model: Model; slot: int): Material = Material(wgr_model_get_material(model.raw, slot.cint))
proc setVisible*(model: Model; visible: bool): bool {.discardable.} = wgr_model_set_visible(model.raw, visible)
proc isVisible*(model: Model): bool = wgr_model_is_visible(model.raw)
proc setPickable*(model: Model; pickable: bool): bool {.discardable.} = wgr_model_set_pickable(model.raw, pickable)
proc isPickable*(model: Model): bool = wgr_model_is_pickable(model.raw)
proc setEnabled*(model: Model; enabled: bool): bool {.discardable.} = wgr_model_set_enabled(model.raw, enabled)
proc isEnabled*(model: Model): bool = wgr_model_is_enabled(model.raw)
proc setCastsShadow*(model: Model; casts: bool): bool {.discardable.} = wgr_model_set_casts_shadow(model.raw, casts)
proc castsShadow*(model: Model): bool = wgr_model_casts_shadow(model.raw)
proc setReceivesShadow*(model: Model; receives: bool): bool {.discardable.} =
  wgr_model_set_receives_shadow(model.raw, receives)
proc receivesShadow*(model: Model): bool = wgr_model_receives_shadow(model.raw)
proc draw*(model: Model) =
  ## immediate, in 3D mode, for one not in a scene: unlit (base color x tint)
  wgr_model_draw(model.raw)
proc destroy*(model: Model) = wgr_model_destroy(model.raw)
proc getAnimationCount*(model: Model): int = wgr_model_get_animation_count(model.raw).int
proc setAnimationTime*(model: Model; seconds: float): bool {.discardable.} =
  wgr_model_set_animation_time(model.raw, seconds.cfloat)
proc getAnimationTime*(model: Model): float = wgr_model_get_animation_time(model.raw).float
proc getAnimationDuration*(model: Model; animation: int): float =
  wgr_model_get_animation_duration(model.raw, animation.cint).float
proc isReady*(model: Model): bool = wgr_model_is_ready(model.raw) ## its mesh has loaded

# --- materials and shaders (wgr_material.h, wgr_shader.h) ---
# Parameters by name: the built-in shading's ("base_color", "roughness",
# "base_color_texture", ...) or a custom shader's own.

proc newMaterial*(shading = MaterialShading.Pbr): Material =
  Material(wgr_material_create(ord(shading).cint))
proc newShader*(path: string): Shader = Shader(wgr_shader_create(path.cstring)) ## a .wgrshader
proc release*(shader: Shader) = wgr_shader_release(shader.raw)
proc newMaterial*(shader: Shader): Material =
  ## drawn by a custom shader: its parameters are the ones the shader declares
  Material(wgr_material_create_custom(shader.raw))
proc getShader*(material: Material): Shader = Shader(wgr_material_get_shader(material.raw))
proc release*(material: Material) = wgr_material_release(material.raw)
proc setShading*(material: Material; shading: MaterialShading): bool {.discardable.} =
  wgr_material_set_shading(material.raw, ord(shading).cint)
proc getShading*(material: Material): MaterialShading =
  MaterialShading(wgr_material_get_shading(material.raw))
proc setAlphaMode*(material: Material; mode: AlphaMode; cutoff = 0.5): bool {.discardable.} =
  wgr_material_set_alpha_mode(material.raw, ord(mode).cint, cutoff.cfloat)
proc getAlphaMode*(material: Material): AlphaMode = AlphaMode(wgr_material_get_alpha_mode(material.raw))
proc setDoubleSided*(material: Material; doubleSided: bool): bool {.discardable.} =
  wgr_material_set_double_sided(material.raw, doubleSided)
proc isDoubleSided*(material: Material): bool = wgr_material_is_double_sided(material.raw)
proc setInt*(material: Material; name: string; value: int): bool {.discardable.} =
  wgr_material_set_int(material.raw, name.cstring, value.cint)
proc setFloat*(material: Material; name: string; value: float): bool {.discardable.} =
  wgr_material_set_float(material.raw, name.cstring, value.cfloat)
proc setVec2*(material: Material; name: string; value: Vec2): bool {.discardable.} =
  wgr_material_set_vec2(material.raw, name.cstring, value.x, value.y)
proc setVec3*(material: Material; name: string; value: Vec3): bool {.discardable.} =
  wgr_material_set_vec3(material.raw, name.cstring, value.x, value.y, value.z)
proc setVec4*(material: Material; name: string; value: Vec4): bool {.discardable.} =
  wgr_material_set_vec4(material.raw, name.cstring, value.x, value.y, value.z, value.w)
proc setColor*(material: Material; name: string; color: Color): bool {.discardable.} =
  ## a vec3 or vec4 parameter (a vec3 ignores alpha)
  wgr_material_set_color(material.raw, name.cstring, color)
proc setTexture*(material: Material; name: string; texture: Texture): bool {.discardable.} =
  wgr_material_set_texture(material.raw, name.cstring, texture.raw)
proc setTextureSampling*(material: Material; name: string; wrapU, wrapV: TextureWrap;
                         filter: TextureFilter): bool {.discardable.} =
  ## how texture `name` is sampled (default Repeat, Linear)
  wgr_material_set_texture_sampling(material.raw, name.cstring, ord(wrapU).cint, ord(wrapV).cint,
                                   ord(filter).cint)

# --- texture / sprite3d ---

proc newTexture*(path: string): Texture = Texture(wgr_texture_create(path.cstring))
proc release*(texture: Texture) = wgr_texture_release(texture.raw)
proc newTextureTarget*(width, height: int): Texture =
  ## a texture to render into (a scene's target)
  Texture(wgr_texture_create_target(width.cint, height.cint))
proc getDefaultTexture*(): Texture = Texture(wgr_texture_get_default()) ## plain white
proc getPlaceholderTexture*(): Texture =
  ## what stands in for a texture that couldn't be loaded
  Texture(wgr_texture_get_placeholder())
proc setPlaceholderTexture*(texture: Texture): bool {.discardable.} =
  wgr_texture_set_placeholder(texture.raw)
proc setSampling*(texture: Texture; wrapU, wrapV: TextureWrap; filter: TextureFilter): bool {.discardable.} =
  ## how it's sampled where it's drawn directly (sprites, draw); default Clamp, Linear
  wgr_texture_set_sampling(texture.raw, ord(wrapU).cint, ord(wrapV).cint, ord(filter).cint)
proc getSize*(texture: Texture): Vec2 = wgr_texture_get_size(texture.raw).toNim
proc draw*(texture: Texture; x, y, width, height: float; tint = ColorWhite) =
  ## the whole texture into that rectangle of the screen
  wgr_texture_draw(texture.raw, x.cfloat, y.cfloat, width.cfloat, height.cfloat, tint)
proc draw*(texture: Texture; source, target: Rect; tint = ColorWhite) =
  ## a region of the texture (its pixels) into a rectangle of the screen
  wgr_texture_draw_ex(texture.raw, source.x, source.y, source.width, source.height,
                     target.x, target.y, target.width, target.height, tint)
proc drawNineSlice*(texture: Texture; source: Rect; left, top, right, bottom: float;
                    target: Rect; tint = ColorWhite) =
  ## the source's corners kept, its edges and middle stretched to fill the target
  wgr_texture_draw_nine_slice(texture.raw, source.x, source.y, source.width, source.height,
                             left, top, right, bottom, target.x, target.y, target.width,
                             target.height, tint)
proc newSprite3d*(texture: Texture): Sprite3d = Sprite3d(wgr_sprite3d_create(texture.raw))
proc newSprite3d*(): Sprite3d = Sprite3d(wgr_sprite3d_create(0)) ## its texture set later (setTexture)
proc setFacing*(sprite: Sprite3d; facing: SpriteFacing): bool {.discardable.} =
  wgr_sprite3d_set_facing(sprite.raw, ord(facing).cint)
proc setTransform*(sprite: Sprite3d; position, rotation, scale: Vec3): bool {.discardable.} =
  ## position, rotation (radians) and scale in one call: the cheapest way to move it every frame
  wgr_sprite3d_set_transform(sprite.raw, position.x, position.y, position.z,
                            rotation.x, rotation.y, rotation.z, scale.x, scale.y, scale.z)
proc setPosition*(sprite: Sprite3d; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are
  wgr_sprite3d_set_position(sprite.raw, value.x, value.y, value.z)
proc setPosition*(sprite: Sprite3d; x, y, z: float): bool {.discardable.} =
  wgr_sprite3d_set_position(sprite.raw, x, y, z)
proc setRotation*(sprite: Sprite3d; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are (radians)
  wgr_sprite3d_set_rotation(sprite.raw, value.x, value.y, value.z)
proc setRotation*(sprite: Sprite3d; x, y, z: float): bool {.discardable.} =
  wgr_sprite3d_set_rotation(sprite.raw, x, y, z)
proc setScale*(sprite: Sprite3d; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are
  wgr_sprite3d_set_scale(sprite.raw, value.x, value.y, value.z)
proc setScale*(sprite: Sprite3d; x, y, z: float): bool {.discardable.} =
  wgr_sprite3d_set_scale(sprite.raw, x, y, z)
proc getPosition*(sprite: Sprite3d): Vec3 = wgr_sprite3d_get_position(sprite.raw).toNim
proc getRotation*(sprite: Sprite3d): Vec3 = wgr_sprite3d_get_rotation(sprite.raw).toNim
proc getScale*(sprite: Sprite3d): Vec3 = wgr_sprite3d_get_scale(sprite.raw).toNim
proc setTint*(sprite: Sprite3d; color: Color): bool {.discardable.} =
  wgr_sprite3d_set_tint(sprite.raw, color)
proc destroy*(sprite: Sprite3d) = wgr_sprite3d_destroy(sprite.raw)
proc setTexture*(sprite: Sprite3d; texture: Texture): bool {.discardable.} =
  wgr_sprite3d_set_texture(sprite.raw, texture.raw)
proc setSize*(sprite: Sprite3d; size: float): bool {.discardable.} =
  ## its larger side, in world units, the other kept in proportion
  wgr_sprite3d_set_size(sprite.raw, size.cfloat)
proc setExtent*(sprite: Sprite3d; width, height: float): bool {.discardable.} =
  ## width and height in world units
  wgr_sprite3d_set_extent(sprite.raw, width.cfloat, height.cfloat)
proc setSource*(sprite: Sprite3d; x, y, width, height: float): bool {.discardable.} =
  wgr_sprite3d_set_source(sprite.raw, x.cfloat, y.cfloat, width.cfloat, height.cfloat)
proc setPivot*(sprite: Sprite3d; x, y: float): bool {.discardable.} =
  wgr_sprite3d_set_pivot(sprite.raw, x.cfloat, y.cfloat)
proc setVisible*(sprite: Sprite3d; visible: bool): bool {.discardable.} = wgr_sprite3d_set_visible(sprite.raw, visible)
proc isVisible*(sprite: Sprite3d): bool = wgr_sprite3d_is_visible(sprite.raw)
proc setPickable*(sprite: Sprite3d; pickable: bool): bool {.discardable.} =
  wgr_sprite3d_set_pickable(sprite.raw, pickable)
proc isPickable*(sprite: Sprite3d): bool = wgr_sprite3d_is_pickable(sprite.raw)
proc setEnabled*(sprite: Sprite3d; enabled: bool): bool {.discardable.} = wgr_sprite3d_set_enabled(sprite.raw, enabled)
proc isEnabled*(sprite: Sprite3d): bool = wgr_sprite3d_is_enabled(sprite.raw)
proc setAlphaMode*(sprite: Sprite3d; mode: AlphaMode; cutoff = 0.5): bool {.discardable.} =
  wgr_sprite3d_set_alpha_mode(sprite.raw, ord(mode).cint, cutoff.cfloat)
proc getAlphaMode*(sprite: Sprite3d): AlphaMode = AlphaMode(wgr_sprite3d_get_alpha_mode(sprite.raw))
proc setMaterial*(sprite: Sprite3d; material: Material): bool {.discardable.} =
  ## lit by a material instead of drawn unlit
  wgr_sprite3d_set_material(sprite.raw, material.raw)
proc getMaterial*(sprite: Sprite3d): Material = Material(wgr_sprite3d_get_material(sprite.raw))
proc setPickAlphaTest*(sprite: Sprite3d; enable: bool; threshold = 0.5): bool {.discardable.} =
  wgr_sprite3d_set_pick_alpha_test(sprite.raw, enable, threshold.cfloat)
proc draw*(sprite: Sprite3d) = wgr_sprite3d_draw(sprite.raw) ## immediate, in 3D mode

# --- fonts / text ---
# drawText and measureText without a font use the built-in one; on a font, that font.

proc newFont*(path: string): Font = Font(wgr_font_create(path.cstring))

proc drawText*(text: string; x, y, size: int; color: Color) =
  wgr_text_draw(text.cstring, x.cint, y.cint, size.cint, color)
proc measureText*(text: string; size: int): int =
  ## width in the built-in font
  wgr_text_measure(text.cstring, size.cint).int
proc drawText*(font: Font; text: string; x, y, size: float; color: Color) =
  wgr_text_draw_ex(font.raw, text.cstring, x.cfloat, y.cfloat, size.cfloat, color)
proc measureText*(font: Font; text: string; size: float): Vec2 =
  wgr_text_measure_ex(font.raw, text.cstring, size.cfloat).toNim
proc drawFps*(x, y: int) =
  ## in the built-in font
  wgr_text_draw_fps(x.cint, y.cint)
proc drawFps*(font: Font; x, y, size: float; color: Color) =
  ## font none: the built-in font
  wgr_text_draw_fps_ex(font.raw, x.cfloat, y.cfloat, size.cfloat, color)

# --- camera / light / scene ---

proc newCamera3d*(projection = Projection.Perspective): Camera3d =
  Camera3d(wgr_camera3d_create(ord(projection).cint))
proc setView*(camera: Camera3d; position, target: Vec3;
              up: Vec3 = (0.0, 1.0, 0.0)): bool {.discardable.} =
  wgr_camera3d_set_view(camera.raw, position.x, position.y, position.z,
                       target.x, target.y, target.z, up.x, up.y, up.z)
proc destroy*(camera: Camera3d) = wgr_camera3d_destroy(camera.raw)
proc getDefaultCamera3d*(): Camera3d =
  ## the one drawing uses when none is set active: at (0, 0, 10) looking at the origin
  Camera3d(wgr_camera3d_get_default())
proc setActive*(camera: Camera3d): bool {.discardable.} =
  ## what immediate 3D drawing (beginMode3d) goes through
  wgr_camera3d_set_active(camera.raw)
proc getActiveCamera3d*(): Camera3d = Camera3d(wgr_camera3d_get_active())
proc setProjection*(camera: Camera3d; projection: Projection): bool {.discardable.} =
  wgr_camera3d_set_projection(camera.raw, ord(projection).cint)
proc getProjection*(camera: Camera3d): Projection = Projection(wgr_camera3d_get_projection(camera.raw))
proc setFov*(camera: Camera3d; fov: float): bool {.discardable.} =
  ## the perspective's vertical field of view, radians (default pi/4)
  wgr_camera3d_set_fov(camera.raw, fov.cfloat)
proc getFov*(camera: Camera3d): float = wgr_camera3d_get_fov(camera.raw).float
proc setOrthoHeight*(camera: Camera3d; height: float): bool {.discardable.} =
  ## how much of the world an orthographic view shows top to bottom (default 10)
  wgr_camera3d_set_ortho_height(camera.raw, height.cfloat)
proc getOrthoHeight*(camera: Camera3d): float = wgr_camera3d_get_ortho_height(camera.raw).float

proc newLight*(kind: LightKind): Light = Light(wgr_light_create(ord(kind).cint))
proc setDirection*(light: Light; direction: Vec3): bool {.discardable.} =
  wgr_light_set_direction(light.raw, direction.x, direction.y, direction.z)
proc setIntensity*(light: Light; intensity: float): bool {.discardable.} =
  wgr_light_set_intensity(light.raw, intensity.cfloat)
proc destroy*(light: Light) = wgr_light_destroy(light.raw)
proc getKind*(light: Light): LightKind = LightKind(wgr_light_get_type(light.raw))
proc getIntensity*(light: Light): float = wgr_light_get_intensity(light.raw).float
proc setColor*(light: Light; color: Color): bool {.discardable.} = wgr_light_set_color(light.raw, color)
proc getColor*(light: Light): Color = wgr_light_get_color(light.raw)
proc setPosition*(light: Light; value: Vec3): bool {.discardable.} =
  ## a point or spot light's; a directional one has none
  wgr_light_set_position(light.raw, value.x, value.y, value.z)
proc setPosition*(light: Light; x, y, z: float): bool {.discardable.} = wgr_light_set_position(light.raw, x, y, z)
proc getPosition*(light: Light): Vec3 = wgr_light_get_position(light.raw).toNim
proc getDirection*(light: Light): Vec3 = wgr_light_get_direction(light.raw).toNim
proc setRange*(light: Light; range: float): bool {.discardable.} =
  ## how far a point or spot light reaches
  wgr_light_set_range(light.raw, range.cfloat)
proc getRange*(light: Light): float = wgr_light_get_range(light.raw).float
proc setSpotCone*(light: Light; innerAngle, outerAngle: float): bool {.discardable.} =
  ## full brightness inside `innerAngle`, fading to none at `outerAngle` (radians)
  wgr_light_set_spot_cone(light.raw, innerAngle.cfloat, outerAngle.cfloat)
proc getSpotInnerAngle*(light: Light): float = wgr_light_get_spot_inner_angle(light.raw).float
proc getSpotOuterAngle*(light: Light): float = wgr_light_get_spot_outer_angle(light.raw).float
proc setEnabled*(light: Light; enabled: bool): bool {.discardable.} = wgr_light_set_enabled(light.raw, enabled)
proc isEnabled*(light: Light): bool = wgr_light_is_enabled(light.raw)
proc setCastsShadows*(light: Light; casts: bool): bool {.discardable.} =
  wgr_light_set_casts_shadows(light.raw, casts)
proc castsShadows*(light: Light): bool = wgr_light_get_casts_shadows(light.raw)
proc setShadowDistance*(light: Light; distance: float): bool {.discardable.} =
  wgr_light_set_shadow_distance(light.raw, distance.cfloat)
proc getShadowDistance*(light: Light): float = wgr_light_get_shadow_distance(light.raw).float
proc setShadowMapSize*(light: Light; size: int): bool {.discardable.} =
  wgr_light_set_shadow_map_size(light.raw, size.cint)
proc getShadowMapSize*(light: Light): int = wgr_light_get_shadow_map_size(light.raw).int
proc setShadowStrength*(light: Light; strength: float): bool {.discardable.} =
  wgr_light_set_shadow_strength(light.raw, strength.cfloat)
proc getShadowStrength*(light: Light): float = wgr_light_get_shadow_strength(light.raw).float
proc setShadowColor*(light: Light; color: Color): bool {.discardable.} = wgr_light_set_shadow_color(light.raw, color)
proc getShadowColor*(light: Light): Color = wgr_light_get_shadow_color(light.raw)
proc setShadowBias*(light: Light; constant, slope: float): bool {.discardable.} =
  wgr_light_set_shadow_bias(light.raw, constant.cfloat, slope.cfloat)
proc getShadowBiasConstant*(light: Light): float = wgr_light_get_shadow_bias_constant(light.raw).float
proc getShadowBiasSlope*(light: Light): float = wgr_light_get_shadow_bias_slope(light.raw).float

proc newScene*(): Scene = Scene(wgr_scene_create())
proc setActiveCamera*(scene: Scene; camera: Camera3d) =
  wgr_scene_set_active_camera(scene.raw, camera.raw)
proc add*(scene: Scene; member: SceneMember; layer = 0): bool {.discardable.} =
  wgr_scene_add(scene.raw, member.raw, layer.cint)
proc setAmbient*(scene: Scene; color: Color; intensity: float): bool {.discardable.} =
  wgr_scene_set_ambient(scene.raw, color, intensity.cfloat)
proc draw*(scene: Scene) = wgr_scene_draw(scene.raw)
proc pick*(scene: Scene; x, y: float; camera = Camera3d(0)): PickResult =
  ## camera none: the scene's active camera. Compare `handle` with typed handles:
  ## `pick.handle == model`.
  let r = wgr_scene_pick(scene.raw, camera.raw, x.cfloat, y.cfloat)
  PickResult(hit: r.hit, handle: Handle(r.handle), distance: r.distance.float,
             pointLocal: r.point_local.toNim, pointWorld: r.point_world.toNim,
             normalLocal: r.normal_local.toNim, normalWorld: r.normal_world.toNim)

# --- particles: emitters (wgr_emitter3d.h, wgr_emitter2d.h) ---
# The two share every call but the ones with a position or a direction, which take a
# Vec3 in the world or a Vec2 in pixels.

proc newEmitter3d*(texture: Texture): Emitter3d = Emitter3d(wgr_emitter3d_create(texture.raw))
proc newEmitter2d*(texture: Texture): Emitter2d = Emitter2d(wgr_emitter2d_create(texture.raw))
proc destroy*(e: Emitter3d) = wgr_emitter3d_destroy(e.raw)
proc destroy*(e: Emitter2d) = wgr_emitter2d_destroy(e.raw)

proc setSource*(e: Emitter; x, y, width, height: float): bool {.discardable.} =
  ## the region of the texture each particle shows, in texture pixels; width or height
  ## <= 0: the whole texture
  (when e is Emitter3d: wgr_emitter3d_set_source(e.raw, x.cfloat, y.cfloat, width.cfloat, height.cfloat)
   else: wgr_emitter2d_set_source(e.raw, x.cfloat, y.cfloat, width.cfloat, height.cfloat))
proc setFrames*(e: Emitter; columns, rows: int; count = 0; perSecond = 0.0): bool {.discardable.} =
  ## a flipbook: the source in columns x rows frames, the first `count` used (0: all);
  ## perSecond 0 plays them once over each particle's life, above 0 loops at that rate
  (when e is Emitter3d: wgr_emitter3d_set_frames(e.raw, columns.cint, rows.cint, count.cint, perSecond.cfloat)
   else: wgr_emitter2d_set_frames(e.raw, columns.cint, rows.cint, count.cint, perSecond.cfloat))

proc setPosition*(e: Emitter3d; value: Vec3): bool {.discardable.} =
  ## a move: the steady spawns spread along the way, and particles inherit its velocity
  wgr_emitter3d_set_position(e.raw, value.x, value.y, value.z)
proc setPosition*(e: Emitter3d; x, y, z: float): bool {.discardable.} =
  wgr_emitter3d_set_position(e.raw, x, y, z)
proc setPosition*(e: Emitter2d; value: Vec2): bool {.discardable.} =
  ## a move: the steady spawns spread along the way, and particles inherit its velocity
  wgr_emitter2d_set_position(e.raw, value.x, value.y)
proc setPosition*(e: Emitter2d; x, y: float): bool {.discardable.} =
  wgr_emitter2d_set_position(e.raw, x, y)
proc jump*(e: Emitter3d; value: Vec3): bool {.discardable.} =
  ## put it somewhere without a move: nothing spawns along the way
  wgr_emitter3d_jump(e.raw, value.x, value.y, value.z)
proc jump*(e: Emitter3d; x, y, z: float): bool {.discardable.} = wgr_emitter3d_jump(e.raw, x, y, z)
proc jump*(e: Emitter2d; value: Vec2): bool {.discardable.} =
  ## put it somewhere without a move: nothing spawns along the way
  wgr_emitter2d_jump(e.raw, value.x, value.y)
proc jump*(e: Emitter2d; x, y: float): bool {.discardable.} = wgr_emitter2d_jump(e.raw, x, y)
proc getPosition*(e: Emitter3d): Vec3 = wgr_emitter3d_get_position(e.raw).toNim
proc getPosition*(e: Emitter2d): Vec2 = wgr_emitter2d_get_position(e.raw).toNim

proc setRate*(e: Emitter; perSecond: float): bool {.discardable.} =
  ## the steady rate, particles per second (0: bursts only)
  (when e is Emitter3d: wgr_emitter3d_set_rate(e.raw, perSecond.cfloat)
   else: wgr_emitter2d_set_rate(e.raw, perSecond.cfloat))
proc burst*(e: Emitter; count: int): bool {.discardable.} =
  (when e is Emitter3d: wgr_emitter3d_burst(e.raw, count.cint)
   else: wgr_emitter2d_burst(e.raw, count.cint))
proc setEmitting*(e: Emitter; emitting: bool): bool {.discardable.} =
  ## false stops the steady rate; the particles alive finish their lives
  (when e is Emitter3d: wgr_emitter3d_set_emitting(e.raw, emitting)
   else: wgr_emitter2d_set_emitting(e.raw, emitting))
proc isEmitting*(e: Emitter): bool =
  (when e is Emitter3d: wgr_emitter3d_is_emitting(e.raw)
   else: wgr_emitter2d_is_emitting(e.raw))
proc setMax*(e: Emitter; count: int): bool {.discardable.} =
  ## at most this many alive (default 1024); false, and refused, below 1 or above 65536
  (when e is Emitter3d: wgr_emitter3d_set_max(e.raw, count.cint)
   else: wgr_emitter2d_set_max(e.raw, count.cint))
proc setLife*(e: Emitter; minSeconds, maxSeconds: float): bool {.discardable.} =
  (when e is Emitter3d: wgr_emitter3d_set_life(e.raw, minSeconds.cfloat, maxSeconds.cfloat)
   else: wgr_emitter2d_set_life(e.raw, minSeconds.cfloat, maxSeconds.cfloat))
proc prewarm*(e: Emitter; seconds: float): bool {.discardable.} =
  ## start over as if the steady rate had run for that long
  (when e is Emitter3d: wgr_emitter3d_prewarm(e.raw, seconds.cfloat)
   else: wgr_emitter2d_prewarm(e.raw, seconds.cfloat))

proc setSpawnBox*(e: Emitter3d; halfExtents: Vec3): bool {.discardable.} =
  ## born anywhere in a box around the position (half sizes; default a point)
  wgr_emitter3d_set_spawn_box(e.raw, halfExtents.x, halfExtents.y, halfExtents.z)
proc setSpawnBox*(e: Emitter2d; halfExtents: Vec2): bool {.discardable.} =
  ## born anywhere in a box around the position (half sizes; default a point)
  wgr_emitter2d_set_spawn_box(e.raw, halfExtents.x, halfExtents.y)
proc setSpawnSphere*(e: Emitter3d; radius: float): bool {.discardable.} =
  wgr_emitter3d_set_spawn_sphere(e.raw, radius.cfloat)
proc setSpawnCircle*(e: Emitter2d; radius: float): bool {.discardable.} =
  wgr_emitter2d_set_spawn_circle(e.raw, radius.cfloat)
proc setVelocity*(e: Emitter3d; velocity: Vec3; spread = 0.0; speedVariance = 0.0): bool {.discardable.} =
  ## along `velocity` at its length's speed, turned up to `spread` radians off it and
  ## faster or slower by up to `speedVariance` (0..1) of it
  wgr_emitter3d_set_velocity(e.raw, velocity.x, velocity.y, velocity.z, spread, speedVariance)
proc setVelocity*(e: Emitter2d; velocity: Vec2; spread = 0.0; speedVariance = 0.0): bool {.discardable.} =
  ## along `velocity` at its length's speed (pixels per second), turned up to `spread`
  ## radians off it and faster or slower by up to `speedVariance` (0..1) of it
  wgr_emitter2d_set_velocity(e.raw, velocity.x, velocity.y, spread, speedVariance)
proc setGravity*(e: Emitter3d; acceleration: Vec3): bool {.discardable.} =
  wgr_emitter3d_set_gravity(e.raw, acceleration.x, acceleration.y, acceleration.z)
proc setGravity*(e: Emitter2d; acceleration: Vec2): bool {.discardable.} =
  wgr_emitter2d_set_gravity(e.raw, acceleration.x, acceleration.y)
proc setDrag*(e: Emitter; perSecond: float): bool {.discardable.} =
  ## slows particles in proportion to their speed (1 loses about 63% a second)
  (when e is Emitter3d: wgr_emitter3d_set_drag(e.raw, perSecond.cfloat)
   else: wgr_emitter2d_set_drag(e.raw, perSecond.cfloat))
proc setInheritVelocity*(e: Emitter; fraction: float): bool {.discardable.} =
  ## that fraction of the emitter's own movement, added at birth
  (when e is Emitter3d: wgr_emitter3d_set_inherit_velocity(e.raw, fraction.cfloat)
   else: wgr_emitter2d_set_inherit_velocity(e.raw, fraction.cfloat))

proc setSize*(e: Emitter; start, finish: float; variance = 0.0): bool {.discardable.} =
  ## from `start` at birth to `finish` at death, each particle's scaled by up to
  ## `variance` (0..1)
  (when e is Emitter3d: wgr_emitter3d_set_size(e.raw, start.cfloat, finish.cfloat, variance.cfloat)
   else: wgr_emitter2d_set_size(e.raw, start.cfloat, finish.cfloat, variance.cfloat))
proc setColor*(e: Emitter; start, finish: Color): bool {.discardable.} =
  ## from `start` at birth to `finish` at death, alpha included (a fade)
  (when e is Emitter3d: wgr_emitter3d_set_color(e.raw, start, finish)
   else: wgr_emitter2d_set_color(e.raw, start, finish))
proc addSizeKey*(e: Emitter; t, size: float): bool {.discardable.} =
  ## a curve point at `t` (0..1 of a particle's life), up to 8; clearSizeKeys first
  (when e is Emitter3d: wgr_emitter3d_add_size_key(e.raw, t.cfloat, size.cfloat)
   else: wgr_emitter2d_add_size_key(e.raw, t.cfloat, size.cfloat))
proc clearSizeKeys*(e: Emitter): bool {.discardable.} =
  (when e is Emitter3d: wgr_emitter3d_clear_size_keys(e.raw)
   else: wgr_emitter2d_clear_size_keys(e.raw))
proc addColorKey*(e: Emitter; t: float; color: Color): bool {.discardable.} =
  ## a curve point at `t` (0..1 of a particle's life), up to 8; clearColorKeys first
  (when e is Emitter3d: wgr_emitter3d_add_color_key(e.raw, t.cfloat, color)
   else: wgr_emitter2d_add_color_key(e.raw, t.cfloat, color))
proc clearColorKeys*(e: Emitter): bool {.discardable.} =
  (when e is Emitter3d: wgr_emitter3d_clear_color_keys(e.raw)
   else: wgr_emitter2d_clear_color_keys(e.raw))
proc addPaletteColor*(e: Emitter; color: Color): bool {.discardable.} =
  ## up to 8; each particle picks one at birth, and it tints the color over its life
  (when e is Emitter3d: wgr_emitter3d_add_palette_color(e.raw, color)
   else: wgr_emitter2d_add_palette_color(e.raw, color))
proc clearPalette*(e: Emitter): bool {.discardable.} =
  (when e is Emitter3d: wgr_emitter3d_clear_palette(e.raw)
   else: wgr_emitter2d_clear_palette(e.raw))
proc setSpin*(e: Emitter; min, max: float): bool {.discardable.} =
  ## radians per second, between min and max, from a random angle
  (when e is Emitter3d: wgr_emitter3d_set_spin(e.raw, min.cfloat, max.cfloat)
   else: wgr_emitter2d_set_spin(e.raw, min.cfloat, max.cfloat))
proc setStretch*(e: Emitter; seconds: float): bool {.discardable.} =
  ## streaks along the motion, as long as the distance moved in `seconds` (0: off)
  (when e is Emitter3d: wgr_emitter3d_set_stretch(e.raw, seconds.cfloat)
   else: wgr_emitter2d_set_stretch(e.raw, seconds.cfloat))
proc setAlphaMode*(e: Emitter; mode: AlphaMode; cutoff = 0.5): bool {.discardable.} =
  ## default AlphaMode.Add
  (when e is Emitter3d: wgr_emitter3d_set_alpha_mode(e.raw, ord(mode).cint, cutoff.cfloat)
   else: wgr_emitter2d_set_alpha_mode(e.raw, ord(mode).cint, cutoff.cfloat))
proc setSeed*(e: Emitter; seed: uint32): bool {.discardable.} =
  (when e is Emitter3d: wgr_emitter3d_set_seed(e.raw, seed.cuint)
   else: wgr_emitter2d_set_seed(e.raw, seed.cuint))

proc getCount*(e: Emitter): int =
  ## particles alive now
  (when e is Emitter3d: wgr_emitter3d_get_count(e.raw)
   else: wgr_emitter2d_get_count(e.raw)).int
proc clear*(e: Emitter) =
  ## all of them gone
  (when e is Emitter3d: wgr_emitter3d_clear(e.raw)
   else: wgr_emitter2d_clear(e.raw))
proc setVisible*(e: Emitter; visible: bool): bool {.discardable.} =
  (when e is Emitter3d: wgr_emitter3d_set_visible(e.raw, visible)
   else: wgr_emitter2d_set_visible(e.raw, visible))
proc draw*(e: Emitter) =
  ## immediate (a 3D one in 3D mode), for one not in a scene
  (when e is Emitter3d: wgr_emitter3d_draw(e.raw)
   else: wgr_emitter2d_draw(e.raw))

# --- 2D shapes, immediate (wgr_shape2d.h) ---
# Screen space: logical pixels, top-left origin, y down. Drawn between beginFrame and
# endFrame, in call order.

proc drawRectangle*(x, y, width, height: float; color: Color) =
  wgr_shape2d_draw_rectangle(x.cfloat, y.cfloat, width.cfloat, height.cfloat, color)
proc drawRectangleLines*(x, y, width, height: float; color: Color) =
  wgr_shape2d_draw_rectangle_lines(x.cfloat, y.cfloat, width.cfloat, height.cfloat, color)
proc drawRoundedRectangle*(x, y, width, height: float;
                           topLeft, topRight, bottomRight, bottomLeft: float; color: Color) =
  ## each corner rounded by its own radius, clamped to half the shorter side
  wgr_shape2d_draw_rounded_rectangle(x.cfloat, y.cfloat, width.cfloat, height.cfloat,
                                    topLeft.cfloat, topRight.cfloat, bottomRight.cfloat,
                                    bottomLeft.cfloat, color)
proc drawRoundedRectangle*(x, y, width, height, radius: float; color: Color) =
  ## every corner rounded by `radius`
  drawRoundedRectangle(x, y, width, height, radius, radius, radius, radius, color)
proc drawBorder*(x, y, width, height: float; left, top, right, bottom: float;
                 topLeft = 0.0; topRight = 0.0; bottomRight = 0.0; bottomLeft = 0.0;
                 color: Color) =
  ## a border just inside the rectangle, each side its own width and each outer corner
  ## its own radius, as in CSS
  wgr_shape2d_draw_border(x.cfloat, y.cfloat, width.cfloat, height.cfloat, left.cfloat, top.cfloat,
                         right.cfloat, bottom.cfloat, topLeft.cfloat, topRight.cfloat,
                         bottomRight.cfloat, bottomLeft.cfloat, color)
proc drawLine*(start, finish: Vec2; color: Color) =
  wgr_shape2d_draw_line(start.x, start.y, finish.x, finish.y, color)
proc drawCircle*(center: Vec2; radius: float; color: Color) =
  wgr_shape2d_draw_circle(center.x, center.y, radius.cfloat, color)
proc drawCircleLines*(center: Vec2; radius: float; color: Color) =
  wgr_shape2d_draw_circle_lines(center.x, center.y, radius.cfloat, color)
proc drawTriangle*(a, b, c: Vec2; color: Color) =
  wgr_shape2d_draw_triangle(a.x, a.y, b.x, b.y, c.x, c.y, color)

# --- window (wgr_window.h) ---
# On the web the canvas is the window: resizing works, moving and other monitors don't.
# Calls a platform can't do return false.

proc setWindowTitle*(title: string) = wgr_window_set_title(title.cstring)
proc isCloseRequested*(): bool = wgr_window_close_requested() != 0 ## the user asked to close it
proc setWindowSize*(width, height: int): bool {.discardable.} =
  wgr_window_set_size(width.cint, height.cint)
proc setWindowPosition*(x, y: int): bool {.discardable.} = wgr_window_set_position(x.cint, y.cint)
proc getWindowPosition*(): Vec2 = wgr_window_get_position().toNim
proc hasFullscreen*(): bool = wgr_window_has_fullscreen() ## whether this platform can
proc requestFullscreen*(fullscreen: bool): bool {.discardable.} =
  ## a request: isFullscreen answers on a later frame
  wgr_window_request_fullscreen(fullscreen)
proc isFullscreen*(): bool = wgr_window_is_fullscreen()
proc setWindowVisible*(visible: bool): bool {.discardable.} =
  ## a hidden window keeps running
  wgr_window_set_visible(visible)
proc isWindowVisible*(): bool = wgr_window_is_visible()
proc isWindowFocused*(): bool = wgr_window_is_focused()
proc getMonitorCount*(): int = wgr_window_get_monitor_count().int
proc getMonitor*(): int = wgr_window_get_monitor().int ## the one the window is on
proc setMonitor*(monitor: int): bool {.discardable.} = wgr_window_set_monitor(monitor.cint)
proc getMonitorSize*(monitor: int): Vec2 = wgr_window_get_monitor_size(monitor.cint).toNim
proc getMonitorPosition*(monitor: int): Vec2 = wgr_window_get_monitor_position(monitor.cint).toNim
proc getMonitorName*(monitor: int): string = $wgr_window_get_monitor_name(monitor.cint)

# --- 2D sprites (wgr_sprite2d.h) ---
# A texture on the screen, in pixels: drawn directly (draw) or as a scene member,
# over the 3D, in layer then insertion order.

proc newSprite2d*(texture: Texture): Sprite2d = Sprite2d(wgr_sprite2d_create(texture.raw))
proc destroy*(sprite: Sprite2d) = wgr_sprite2d_destroy(sprite.raw)
proc setTexture*(sprite: Sprite2d; texture: Texture): bool {.discardable.} =
  wgr_sprite2d_set_texture(sprite.raw, texture.raw)
proc setSource*(sprite: Sprite2d; x, y, width, height: float): bool {.discardable.} =
  ## the region of the texture it shows, in texture pixels
  wgr_sprite2d_set_source(sprite.raw, x.cfloat, y.cfloat, width.cfloat, height.cfloat)
proc setTransform*(sprite: Sprite2d; position: Vec2; rotation: float; scale: Vec2): bool {.discardable.} =
  ## position, rotation (radians, around the pivot) and scale in one call
  wgr_sprite2d_set_transform(sprite.raw, position.x, position.y, rotation, scale.x, scale.y)
proc setPosition*(sprite: Sprite2d; value: Vec2): bool {.discardable.} =
  ## where the pivot goes
  wgr_sprite2d_set_position(sprite.raw, value.x, value.y)
proc setPosition*(sprite: Sprite2d; x, y: float): bool {.discardable.} =
  wgr_sprite2d_set_position(sprite.raw, x, y)
proc setRotation*(sprite: Sprite2d; angle: float): bool {.discardable.} =
  ## radians, around the pivot
  wgr_sprite2d_set_rotation(sprite.raw, angle.cfloat)
proc setScale*(sprite: Sprite2d; value: Vec2): bool {.discardable.} =
  wgr_sprite2d_set_scale(sprite.raw, value.x, value.y)
proc setScale*(sprite: Sprite2d; x, y: float): bool {.discardable.} =
  wgr_sprite2d_set_scale(sprite.raw, x, y)
proc getPosition*(sprite: Sprite2d): Vec2 = wgr_sprite2d_get_position(sprite.raw).toNim
proc getRotation*(sprite: Sprite2d): float = wgr_sprite2d_get_rotation(sprite.raw).float
proc getScale*(sprite: Sprite2d): Vec2 = wgr_sprite2d_get_scale(sprite.raw).toNim
proc setSize*(sprite: Sprite2d; width, height: float): bool {.discardable.} =
  ## drawn at this size, in pixels (default the source's)
  wgr_sprite2d_set_size(sprite.raw, width.cfloat, height.cfloat)
proc setPivot*(sprite: Sprite2d; x, y: float): bool {.discardable.} =
  ## the point the position refers to, as a fraction of its size (0.5, 0.5: the middle)
  wgr_sprite2d_set_pivot(sprite.raw, x.cfloat, y.cfloat)
proc setNineSlice*(sprite: Sprite2d; left, top, right, bottom: float): bool {.discardable.} =
  ## the source's borders kept at their size when it's drawn larger (0s: off)
  wgr_sprite2d_set_nine_slice(sprite.raw, left.cfloat, top.cfloat, right.cfloat, bottom.cfloat)
proc setTint*(sprite: Sprite2d; color: Color): bool {.discardable.} = wgr_sprite2d_set_tint(sprite.raw, color)
proc setVisible*(sprite: Sprite2d; visible: bool): bool {.discardable.} =
  wgr_sprite2d_set_visible(sprite.raw, visible)
proc isVisible*(sprite: Sprite2d): bool = wgr_sprite2d_is_visible(sprite.raw)
proc setPickable*(sprite: Sprite2d; pickable: bool): bool {.discardable.} =
  wgr_sprite2d_set_pickable(sprite.raw, pickable)
proc isPickable*(sprite: Sprite2d): bool = wgr_sprite2d_is_pickable(sprite.raw)
proc setEnabled*(sprite: Sprite2d; enabled: bool): bool {.discardable.} =
  wgr_sprite2d_set_enabled(sprite.raw, enabled)
proc isEnabled*(sprite: Sprite2d): bool = wgr_sprite2d_is_enabled(sprite.raw)
proc setAlphaMode*(sprite: Sprite2d; mode: AlphaMode; cutoff = 0.5): bool {.discardable.} =
  wgr_sprite2d_set_alpha_mode(sprite.raw, ord(mode).cint, cutoff.cfloat)
proc getAlphaMode*(sprite: Sprite2d): AlphaMode = AlphaMode(wgr_sprite2d_get_alpha_mode(sprite.raw))
proc setPickAlphaTest*(sprite: Sprite2d; enable: bool; threshold = 0.5): bool {.discardable.} =
  ## picked only where its texture's alpha is above `threshold`
  wgr_sprite2d_set_pick_alpha_test(sprite.raw, enable, threshold.cfloat)
proc setMaterial*(sprite: Sprite2d; material: Material): bool {.discardable.} =
  wgr_sprite2d_set_material(sprite.raw, material.raw)
proc getMaterial*(sprite: Sprite2d): Material = Material(wgr_sprite2d_get_material(sprite.raw))
proc draw*(sprite: Sprite2d) = wgr_sprite2d_draw(sprite.raw) ## immediate, for one not in a scene

# --- 3D shapes (wgr_shape3d.h) ---
# Immediate: drawn between beginMode3d and endMode3d, in call order. Rotations are
# radians. Or retained, as Shape3d objects a scene holds.

proc drawLine*(start, finish: Vec3; color: Color) =
  wgr_shape3d_draw_line(start.x, start.y, start.z, finish.x, finish.y, finish.z, color)
proc drawCube*(center, size: Vec3; color: Color) =
  wgr_shape3d_draw_cube(center.x, center.y, center.z, size.x, size.y, size.z, color)
proc drawCubeWires*(center, size: Vec3; color: Color) =
  wgr_shape3d_draw_cube_wires(center.x, center.y, center.z, size.x, size.y, size.z, color)
proc drawSphere*(center: Vec3; radius: float; color: Color) =
  wgr_shape3d_draw_sphere(center.x, center.y, center.z, radius.cfloat, color)
proc drawRectangle*(center: Vec3; width, height: float; rotation: Vec3; color: Color) =
  ## flat, facing +Z before its rotation
  wgr_shape3d_draw_rectangle(center.x, center.y, center.z, width.cfloat, height.cfloat,
                            rotation.x, rotation.y, rotation.z, color)
proc drawCircle*(center: Vec3; radius: float; rotation: Vec3; color: Color) =
  ## flat, facing +Z before its rotation
  wgr_shape3d_draw_circle(center.x, center.y, center.z, radius.cfloat, rotation.x, rotation.y,
                         rotation.z, color)

proc newShape3d*(): Shape3d = Shape3d(wgr_shape3d_create())
proc destroy*(shape: Shape3d) = wgr_shape3d_destroy(shape.raw)
proc setCube*(shape: Shape3d; size: Vec3): bool {.discardable.} =
  wgr_shape3d_set_cube(shape.raw, size.x, size.y, size.z)
proc setSphere*(shape: Shape3d; radius: float): bool {.discardable.} =
  wgr_shape3d_set_sphere(shape.raw, radius.cfloat)
proc setRectangle*(shape: Shape3d; width, height: float): bool {.discardable.} =
  wgr_shape3d_set_rectangle(shape.raw, width.cfloat, height.cfloat)
proc setCircle*(shape: Shape3d; radius: float): bool {.discardable.} =
  wgr_shape3d_set_circle(shape.raw, radius.cfloat)
proc setLine*(shape: Shape3d; start, finish: Vec3): bool {.discardable.} =
  wgr_shape3d_set_line(shape.raw, start.x, start.y, start.z, finish.x, finish.y, finish.z)
proc setLineStrip*(shape: Shape3d): bool {.discardable.} =
  ## a line through the points addPoint adds
  wgr_shape3d_set_line_strip(shape.raw)
proc addPoint*(shape: Shape3d; point: Vec3): bool {.discardable.} =
  wgr_shape3d_add_point(shape.raw, point.x, point.y, point.z)
proc getPointCount*(shape: Shape3d): int = wgr_shape3d_get_point_count(shape.raw).int
proc setTransform*(shape: Shape3d; position, rotation, scale: Vec3): bool {.discardable.} =
  wgr_shape3d_set_transform(shape.raw, position.x, position.y, position.z,
                           rotation.x, rotation.y, rotation.z, scale.x, scale.y, scale.z)
proc setPosition*(shape: Shape3d; value: Vec3): bool {.discardable.} =
  wgr_shape3d_set_position(shape.raw, value.x, value.y, value.z)
proc setPosition*(shape: Shape3d; x, y, z: float): bool {.discardable.} =
  wgr_shape3d_set_position(shape.raw, x, y, z)
proc setRotation*(shape: Shape3d; value: Vec3): bool {.discardable.} =
  wgr_shape3d_set_rotation(shape.raw, value.x, value.y, value.z)
proc setScale*(shape: Shape3d; value: Vec3): bool {.discardable.} =
  wgr_shape3d_set_scale(shape.raw, value.x, value.y, value.z)
proc getPosition*(shape: Shape3d): Vec3 = wgr_shape3d_get_position(shape.raw).toNim
proc getRotation*(shape: Shape3d): Vec3 = wgr_shape3d_get_rotation(shape.raw).toNim
proc getScale*(shape: Shape3d): Vec3 = wgr_shape3d_get_scale(shape.raw).toNim
proc setColor*(shape: Shape3d; color: Color): bool {.discardable.} = wgr_shape3d_set_color(shape.raw, color)
proc setVisible*(shape: Shape3d; visible: bool): bool {.discardable.} =
  wgr_shape3d_set_visible(shape.raw, visible)
proc isVisible*(shape: Shape3d): bool = wgr_shape3d_is_visible(shape.raw)
proc setPickable*(shape: Shape3d; pickable: bool): bool {.discardable.} =
  wgr_shape3d_set_pickable(shape.raw, pickable)
proc isPickable*(shape: Shape3d): bool = wgr_shape3d_is_pickable(shape.raw)
proc setEnabled*(shape: Shape3d; enabled: bool): bool {.discardable.} =
  wgr_shape3d_set_enabled(shape.raw, enabled)
proc isEnabled*(shape: Shape3d): bool = wgr_shape3d_is_enabled(shape.raw)
proc draw*(shape: Shape3d) = wgr_shape3d_draw(shape.raw) ## immediate, in 3D mode, for one not in a scene

# --- debug ---

proc enableFps*(x, y, fontSize: int) =
  ## wgrender's own FPS overlay, drawn at the end of every frame
  wgr_debug_enable_fps(x.cint, y.cint, fontSize.cint)

# --- frame ---

proc beginFrame*() = wgr_render_begin_frame()
proc endFrame*() = wgr_render_end_frame()
proc beginMode3d*() = wgr_render_begin_mode_3d() ## immediate 3D drawing, through the scene's camera
proc endMode3d*() = wgr_render_end_mode_3d()
proc drawGrid*(slices: int; spacing: float; color: Color) =
  ## a grid on the ground (XZ), between beginMode3d and endMode3d
  wgr_shape3d_draw_grid(slices.cint, spacing.cfloat, color)
proc clearBackground*(color: Color) = wgr_render_clear_background(color)
proc getScreenSize*(): Vec2 = wgr_window_get_screen_size().toNim

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

# --- gamepads ---
# A pad keeps its slot (0 ..< MaxGamepads) while it's connected. On the web the browser
# lists one only after a button on it is pressed with the page focused.

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
