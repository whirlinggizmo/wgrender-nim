## wgrender for Nim: the C API (wgr/raw) wrapped in stock Nim types.
##
## - strings, ints and floats instead of cstring / cint / cfloat
## - Nim enums and a `set` of window flags instead of C constants
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
  Handle* = WgrHandle ## an untyped wgrender handle (a pick result's hit); 0 is none
  Color* = WgrColor   ## packed 0xRRGGBBAA, a value

  # Resources: loaded, reference counted, shared
  Audio* = distinct Handle
  Mesh* = distinct Handle
  Texture* = distinct Handle
  Font* = distinct Handle
  # Objects: placed or heard, each with its own state
  Sound* = distinct Handle
  Model* = distinct Handle
  Sprite3d* = distinct Handle
  Camera3d* = distinct Handle
  Light* = distinct Handle
  Scene* = distinct Handle
  AssetTask* = distinct Handle

  AnyHandle* = Audio | Mesh | Texture | Font | Sound | Model | Sprite3d |
               Camera3d | Light | Scene | AssetTask
  SceneMember* = Model | Sprite3d | Light ## what a scene's add takes


  Vec2* = tuple[x, y: float]
  Vec3* = tuple[x, y, z: float]

  MouseState* = object
    x*, y*: int
    wheel*, wheelX*: float ## scroll this frame: about one unit per wheel notch
    left*, right*, middle*: int
    buttons*: array[3, int]
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

  KeyboardState* = object
    ## every key at once, plus this frame's pressed keys and chars; for one key,
    ## `getKey` / `isKeyPressed` are simpler
    c: CKeyboardState

  AssetCallback* = proc (path: string) {.closure.}
  InitCallback* = proc () {.closure.}
  FrameCallback* = proc (dt, tickFraction: float) {.closure.}

const
  ColorWhite* = WGR_COLOR_WHITE
  ColorBlack* = WGR_COLOR_BLACK
  ColorBlue* = WGR_COLOR_BLUE
  ColorRaywhite* = WGR_COLOR_RAYWHITE

proc `==`*[T: AnyHandle](a, b: T): bool = a.Handle == b.Handle
proc `==`*(a: Handle; b: AnyHandle): bool = a == b.Handle
proc `==`*(a: AnyHandle; b: Handle): bool = a.Handle == b
proc `$`*(h: AnyHandle): string = $h.Handle
proc isNone*(h: AnyHandle): bool = h.Handle == 0 ## not created (yet), or creation failed

# The asserts include wgr.h themselves: otherwise they depend on some other call in the
# same C file having pulled it in, which a program that only type-checks never does.
{.emit: """
#include "wgr.h"
_Static_assert(WGR_KEY_SPACE == 32, "wgr.nim Key.Space is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_APOSTROPHE == 39, "wgr.nim Key.Apostrophe is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_COMMA == 44, "wgr.nim Key.Comma is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_MINUS == 45, "wgr.nim Key.Minus is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_PERIOD == 46, "wgr.nim Key.Period is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_SLASH == 47, "wgr.nim Key.Slash is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_0 == 48, "wgr.nim Key.Digit0 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_1 == 49, "wgr.nim Key.Digit1 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_2 == 50, "wgr.nim Key.Digit2 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_3 == 51, "wgr.nim Key.Digit3 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_4 == 52, "wgr.nim Key.Digit4 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_5 == 53, "wgr.nim Key.Digit5 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_6 == 54, "wgr.nim Key.Digit6 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_7 == 55, "wgr.nim Key.Digit7 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_8 == 56, "wgr.nim Key.Digit8 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_9 == 57, "wgr.nim Key.Digit9 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_SEMICOLON == 59, "wgr.nim Key.Semicolon is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_EQUAL == 61, "wgr.nim Key.Equal is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_A == 65, "wgr.nim Key.A is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_B == 66, "wgr.nim Key.B is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_C == 67, "wgr.nim Key.C is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_D == 68, "wgr.nim Key.D is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_E == 69, "wgr.nim Key.E is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_F == 70, "wgr.nim Key.F is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_G == 71, "wgr.nim Key.G is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_H == 72, "wgr.nim Key.H is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_I == 73, "wgr.nim Key.I is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_J == 74, "wgr.nim Key.J is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_K == 75, "wgr.nim Key.K is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_L == 76, "wgr.nim Key.L is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_M == 77, "wgr.nim Key.M is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_N == 78, "wgr.nim Key.N is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_O == 79, "wgr.nim Key.O is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_P == 80, "wgr.nim Key.P is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_Q == 81, "wgr.nim Key.Q is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_R == 82, "wgr.nim Key.R is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_S == 83, "wgr.nim Key.S is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_T == 84, "wgr.nim Key.T is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_U == 85, "wgr.nim Key.U is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_V == 86, "wgr.nim Key.V is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_W == 87, "wgr.nim Key.W is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_X == 88, "wgr.nim Key.X is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_Y == 89, "wgr.nim Key.Y is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_Z == 90, "wgr.nim Key.Z is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_LEFT_BRACKET == 91, "wgr.nim Key.LeftBracket is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_BACKSLASH == 92, "wgr.nim Key.Backslash is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_RIGHT_BRACKET == 93, "wgr.nim Key.RightBracket is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_GRAVE_ACCENT == 96, "wgr.nim Key.GraveAccent is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_ESCAPE == 256, "wgr.nim Key.Escape is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_ENTER == 257, "wgr.nim Key.Enter is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_TAB == 258, "wgr.nim Key.Tab is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_BACKSPACE == 259, "wgr.nim Key.Backspace is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_INSERT == 260, "wgr.nim Key.Insert is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_DELETE == 261, "wgr.nim Key.Delete is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_RIGHT == 262, "wgr.nim Key.Right is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_LEFT == 263, "wgr.nim Key.Left is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_DOWN == 264, "wgr.nim Key.Down is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_UP == 265, "wgr.nim Key.Up is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_PAGE_UP == 266, "wgr.nim Key.PageUp is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_PAGE_DOWN == 267, "wgr.nim Key.PageDown is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_HOME == 268, "wgr.nim Key.Home is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_END == 269, "wgr.nim Key.End is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_CAPS_LOCK == 280, "wgr.nim Key.CapsLock is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_F1 == 290, "wgr.nim Key.F1 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_F2 == 291, "wgr.nim Key.F2 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_F3 == 292, "wgr.nim Key.F3 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_F4 == 293, "wgr.nim Key.F4 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_F5 == 294, "wgr.nim Key.F5 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_F6 == 295, "wgr.nim Key.F6 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_F7 == 296, "wgr.nim Key.F7 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_F8 == 297, "wgr.nim Key.F8 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_F9 == 298, "wgr.nim Key.F9 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_F10 == 299, "wgr.nim Key.F10 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_F11 == 300, "wgr.nim Key.F11 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_F12 == 301, "wgr.nim Key.F12 is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_LEFT_SHIFT == 340, "wgr.nim Key.LeftShift is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_LEFT_CONTROL == 341, "wgr.nim Key.LeftControl is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_LEFT_ALT == 342, "wgr.nim Key.LeftAlt is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_LEFT_SUPER == 343, "wgr.nim Key.LeftSuper is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_RIGHT_SHIFT == 344, "wgr.nim Key.RightShift is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_RIGHT_CONTROL == 345, "wgr.nim Key.RightControl is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_RIGHT_ALT == 346, "wgr.nim Key.RightAlt is out of date with wgr_keys.h");
_Static_assert(WGR_KEY_RIGHT_SUPER == 347, "wgr.nim Key.RightSuper is out of date with wgr_keys.h");
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
  result = wgr_asset_add_task(task.Handle, assetSuccessTrampoline, assetFailureTrampoline,
                             cast[pointer](t)) == WGR_ASSET_ADD_TASK_OK
  if not result:
    GC_unref(t)

# --- colors ---

proc rgba*(r, g, b, a: int): Color = wgr_color_rgba(r.cint, g.cint, b.cint, a.cint)

# --- audio / sound ---

proc newAudio*(path: string): Audio = Audio(wgr_audio_create(path.cstring))
proc release*(audio: Audio) = wgr_audio_release(audio.Handle)
proc newSound*(audio: Audio): Sound = Sound(wgr_sound_create(audio.Handle))
proc setLoop*(sound: Sound; loop: bool): bool {.discardable.} = wgr_sound_set_loop(sound.Handle, loop)
proc play*(sound: Sound): bool {.discardable.} = wgr_sound_play(sound.Handle)

# --- mesh / model ---

proc newMesh*(path: string): Mesh = Mesh(wgr_mesh_create(path.cstring))
proc release*(mesh: Mesh) = wgr_mesh_release(mesh.Handle)
proc newModel*(mesh: Mesh): Model = Model(wgr_model_create(mesh.Handle))
proc setAnimation*(model: Model; index: int): bool {.discardable.} =
  wgr_model_set_animation(model.Handle, index.cint)
proc setAnimationSpeed*(model: Model; speed: float): bool {.discardable.} =
  wgr_model_set_animation_speed(model.Handle, speed.cfloat)
proc setAnimationLoop*(model: Model; loop: bool): bool {.discardable.} =
  wgr_model_set_animation_loop(model.Handle, loop)
proc setTransform*(model: Model; position, rotation, scale: Vec3): bool {.discardable.} =
  ## position, rotation (radians) and scale in one call: the cheapest way to move it every frame
  wgr_model_set_transform(model.Handle, position.x, position.y, position.z,
                         rotation.x, rotation.y, rotation.z, scale.x, scale.y, scale.z)
proc setPosition*(model: Model; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are
  wgr_model_set_position(model.Handle, value.x, value.y, value.z)
proc setPosition*(model: Model; x, y, z: float): bool {.discardable.} =
  wgr_model_set_position(model.Handle, x, y, z)
proc setRotation*(model: Model; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are (radians)
  wgr_model_set_rotation(model.Handle, value.x, value.y, value.z)
proc setRotation*(model: Model; x, y, z: float): bool {.discardable.} =
  wgr_model_set_rotation(model.Handle, x, y, z)
proc setScale*(model: Model; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are
  wgr_model_set_scale(model.Handle, value.x, value.y, value.z)
proc setScale*(model: Model; x, y, z: float): bool {.discardable.} =
  wgr_model_set_scale(model.Handle, x, y, z)
proc getPosition*(model: Model): Vec3 = wgr_model_get_position(model.Handle).toNim
proc getRotation*(model: Model): Vec3 = wgr_model_get_rotation(model.Handle).toNim
proc getScale*(model: Model): Vec3 = wgr_model_get_scale(model.Handle).toNim
proc setTint*(model: Model; color: Color): bool {.discardable.} = wgr_model_set_tint(model.Handle, color)
proc animate*(model: Model; dt: float): bool {.discardable.} = wgr_model_animate(model.Handle, dt.cfloat)

# --- texture / sprite3d ---

proc newTexture*(path: string): Texture = Texture(wgr_texture_create(path.cstring))
proc release*(texture: Texture) = wgr_texture_release(texture.Handle)
proc newSprite3d*(texture: Texture): Sprite3d = Sprite3d(wgr_sprite3d_create(texture.Handle))
proc setFacing*(sprite: Sprite3d; facing: SpriteFacing): bool {.discardable.} =
  wgr_sprite3d_set_facing(sprite.Handle, ord(facing).cint)
proc setTransform*(sprite: Sprite3d; position, rotation, scale: Vec3): bool {.discardable.} =
  ## position, rotation (radians) and scale in one call: the cheapest way to move it every frame
  wgr_sprite3d_set_transform(sprite.Handle, position.x, position.y, position.z,
                            rotation.x, rotation.y, rotation.z, scale.x, scale.y, scale.z)
proc setPosition*(sprite: Sprite3d; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are
  wgr_sprite3d_set_position(sprite.Handle, value.x, value.y, value.z)
proc setPosition*(sprite: Sprite3d; x, y, z: float): bool {.discardable.} =
  wgr_sprite3d_set_position(sprite.Handle, x, y, z)
proc setRotation*(sprite: Sprite3d; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are (radians)
  wgr_sprite3d_set_rotation(sprite.Handle, value.x, value.y, value.z)
proc setRotation*(sprite: Sprite3d; x, y, z: float): bool {.discardable.} =
  wgr_sprite3d_set_rotation(sprite.Handle, x, y, z)
proc setScale*(sprite: Sprite3d; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are
  wgr_sprite3d_set_scale(sprite.Handle, value.x, value.y, value.z)
proc setScale*(sprite: Sprite3d; x, y, z: float): bool {.discardable.} =
  wgr_sprite3d_set_scale(sprite.Handle, x, y, z)
proc getPosition*(sprite: Sprite3d): Vec3 = wgr_sprite3d_get_position(sprite.Handle).toNim
proc getRotation*(sprite: Sprite3d): Vec3 = wgr_sprite3d_get_rotation(sprite.Handle).toNim
proc getScale*(sprite: Sprite3d): Vec3 = wgr_sprite3d_get_scale(sprite.Handle).toNim
proc setTint*(sprite: Sprite3d; color: Color): bool {.discardable.} =
  wgr_sprite3d_set_tint(sprite.Handle, color)
proc destroy*(sprite: Sprite3d) = wgr_sprite3d_destroy(sprite.Handle)

# --- fonts / text ---
# drawText and measureText without a font use the built-in one; on a font, that font.

proc newFont*(path: string): Font = Font(wgr_font_create(path.cstring))

proc drawText*(text: string; x, y, size: int; color: Color) =
  wgr_text_draw(text.cstring, x.cint, y.cint, size.cint, color)
proc measureText*(text: string; size: int): int =
  ## width in the built-in font
  wgr_text_measure(text.cstring, size.cint).int
proc drawText*(font: Font; text: string; x, y, size: float; color: Color) =
  wgr_text_draw_ex(font.Handle, text.cstring, x.cfloat, y.cfloat, size.cfloat, color)
proc measureText*(font: Font; text: string; size: float): Vec2 =
  wgr_text_measure_ex(font.Handle, text.cstring, size.cfloat).toNim
proc drawFps*(font: Font; x, y, size: float; color: Color) =
  ## font none: the built-in font
  wgr_text_draw_fps_ex(font.Handle, x.cfloat, y.cfloat, size.cfloat, color)

# --- camera / light / scene ---

proc newCamera3d*(projection = Projection.Perspective): Camera3d =
  Camera3d(wgr_camera3d_create(ord(projection).cint))
proc setView*(camera: Camera3d; position, target: Vec3;
              up: Vec3 = (0.0, 1.0, 0.0)): bool {.discardable.} =
  wgr_camera3d_set_view(camera.Handle, position.x, position.y, position.z,
                       target.x, target.y, target.z, up.x, up.y, up.z)
proc newLight*(kind: LightKind): Light = Light(wgr_light_create(ord(kind).cint))
proc setDirection*(light: Light; direction: Vec3): bool {.discardable.} =
  wgr_light_set_direction(light.Handle, direction.x, direction.y, direction.z)
proc setIntensity*(light: Light; intensity: float): bool {.discardable.} =
  wgr_light_set_intensity(light.Handle, intensity.cfloat)
proc newScene*(): Scene = Scene(wgr_scene_create())
proc setActiveCamera*(scene: Scene; camera: Camera3d) =
  wgr_scene_set_active_camera(scene.Handle, camera.Handle)
proc add*(scene: Scene; member: SceneMember; layer = 0): bool {.discardable.} =
  wgr_scene_add(scene.Handle, member.Handle, layer.cint)
proc setAmbient*(scene: Scene; color: Color; intensity: float): bool {.discardable.} =
  wgr_scene_set_ambient(scene.Handle, color, intensity.cfloat)
proc draw*(scene: Scene) = wgr_scene_draw(scene.Handle)
proc pick*(scene: Scene; x, y: float; camera = Camera3d(0)): PickResult =
  ## camera none: the scene's active camera. Compare `handle` with typed handles:
  ## `pick.handle == model`.
  let r = wgr_scene_pick(scene.Handle, camera.Handle, x.cfloat, y.cfloat)
  PickResult(hit: r.hit, handle: r.handle, distance: r.distance.float,
             pointLocal: r.point_local.toNim, pointWorld: r.point_world.toNim,
             normalLocal: r.normal_local.toNim, normalWorld: r.normal_world.toNim)

# --- frame ---

proc beginFrame*() = wgr_render_begin_frame()
proc endFrame*() = wgr_render_end_frame()
proc clearBackground*(color: Color) = wgr_render_clear_background(color)
proc getScreenSize*(): Vec2 = wgr_window_get_screen_size().toNim

proc getMouseState*(): MouseState =
  let m = wgr_input_get_mouse_state()
  MouseState(x: m.x.int, y: m.y.int, wheel: m.wheel.float, wheelX: m.wheel_x.float,
             left: m.left.int, right: m.right.int, middle: m.middle.int,
             buttons: [m.buttons[0].int, m.buttons[1].int, m.buttons[2].int],
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
