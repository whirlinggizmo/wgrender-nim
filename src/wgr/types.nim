## The types every part of wgr shares: the handle kinds, vectors, enums, colors and
## callbacks, and the key and gamepad enums' checks against wgrender's headers.

import ./raw

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
  Shape2d* = distinct Handle   ## a rectangle, circle or line on the screen
  Text2d* = distinct Handle    ## text on the screen, kept and drawn with the scene
  Text3d* = distinct Handle    ## text in the world
  Environment* = distinct Handle ## an HDR environment: image-based light and a background
  AssetRequest* = distinct Handle ## a download the fetcher is asked for (setFetcher)
  AssetTask* = distinct Handle

  AnyHandle* = Audio | Mesh | Texture | Font | Material | Shader | Environment | Sound | Shape2d |
               Text2d | Text3d | AssetRequest | Model | Sprite3d | Sprite2d |
               Shape3d | Camera3d | Light | Scene | Emitter3d | Emitter2d | AssetTask
  SceneMember* = Model | Sprite3d | Sprite2d | Shape3d | Shape2d | Text2d | Text3d | Light |
                 Emitter3d | Emitter2d
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

  AssetCacheMode* {.pure.} = enum
    ## how a cached asset is treated on a later visit (setAssetCacheMode); the web only
    Revalidate ## the default: used while fresh by its Cache-Control, else checked with
               ## the host (304 keeps, 200 replaces, 4xx deletes, no answer keeps)
    Trust      ## used without asking, however old
    Off        ## nothing kept between visits; what earlier ones kept is left alone

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

  Tonemap* {.pure.} = enum
    None, Neutral, Aces

  AlignX* {.pure.} = enum
    ## where a block of text sits across its position
    Left = 0, Center = 1, Right = 2

  AlignY* {.pure.} = enum
    ## where a block of text sits up and down its position
    Top = 3, Middle = 4, Bottom = 5

  MouseButton* {.pure.} = enum
    Left, Right, Middle

  HandleKind* {.pure.} = enum
    ## what a Handle is (getKind): a pick result's hit, say
    None = 0, Camera3d = 2, Font = 3, Texture = 4, Sprite2d = 5, Sprite3d = 6, Model = 7,
    Mesh = 8, Sound = 9, Text2d = 11, Scene = 12, Shape3d = 13, Text3d = 14, Audio = 15,
    Light = 16, Material = 17, Environment = 18, Shape2d = 19, Emitter3d = 20,
    Emitter2d = 21, Shader = 22, AssetTask = 32

  Touch* = object
    id*: int
    x*, y*: float
    dx*, dy*: float ## moved this frame
    state*: ButtonState

  TouchGesture* = object
    ## two fingers: where between them, moved, pinched and turned this frame
    active*: bool
    x*, y*, dx*, dy*: float
    scale*: float    ## this frame's pinch (1: none)
    rotation*: float ## this frame's turn, radians

  PickStats* = object
    broadphaseTests*, broadphaseRejects*, narrowphaseTests*, narrowphaseHits*: int


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


  AssetCallback* = proc (path: string) {.closure.}
  InitCallback* = proc () {.closure.}
  FrameCallback* = proc (dt, tickFraction: float) {.closure.}
  TickCallback* = proc (dt: float) {.closure.}

const
  MaxGamepads* = 4 ## pads at once, each keeping its slot (0 .. 3) while connected
  MaxTouches* = 8  ## fingers at once (a touch's id is 0 ..< MaxTouches)
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

proc `==`*(a, b: Handle): bool {.borrow.}

proc `$`*(h: Handle): string {.borrow.}

proc isNone*(h: Handle): bool = uint32(h) == 0 ## no handle: nothing hit, or none made

proc `==`*[T: AnyHandle](a, b: T): bool = uint32(Handle(a)) == uint32(Handle(b))

proc `==`*(a: Handle; b: AnyHandle): bool = uint32(Handle(a)) == uint32(Handle(b))

proc `==`*(a: AnyHandle; b: Handle): bool = uint32(Handle(a)) == uint32(Handle(b))

proc `$`*(h: AnyHandle): string = $uint32(Handle(h))

proc isNone*(h: AnyHandle): bool = uint32(Handle(h)) == 0 ## not created (yet), or creation failed

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
typedef char wgr_nim_MaxTouches_is_out_of_date_with_wgr_input_h[(WGR_INPUT_MAX_TOUCHES == 8) ? 1 : -1];
""".}
