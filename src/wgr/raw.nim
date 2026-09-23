## Raw wgrender bindings: the C API as is (C types, C names). Most code wants the
## wrappers in `wgr` instead (Nim types, closures).
## Declarations come straight from wgrender's public headers (`header: "wgr.h"`),
## so the C compiler checks every prototype and struct layout for us.

type
  WgrHandle* = cuint
  WgrColor* = uint32

  CVec2* {.importc: "vec2_t", bycopy, header: "wgr.h".} = object
    x*, y*: cfloat

  CVec3* {.importc: "vec3_t", bycopy, header: "wgr.h".} = object
    x*, y*, z*: cfloat

  CMouseState* {.importc: "wgr_mouse_state_t", bycopy, header: "wgr.h".} = object
    x*, y*: cint
    wheel*, wheel_x*: cfloat
    left*, right*, middle*: cint
    buttons*: array[3, cint]
    dx*, dy*: cint

  CKeyboardState* {.importc: "wgr_keyboard_state_t", bycopy, header: "wgr.h".} = object
    max_num_keys*: cint
    keys*: array[512, cint] ## wgr_button_state_t per key, indexed by key code
    pressed_key*, pressed_char*: cint
    num_pressed_keys*: cint
    pressed_keys*: array[32, cint]
    num_pressed_chars*: cint
    pressed_chars*: array[32, cint]

  CPickResult* {.importc: "wgr_pick_result_t", bycopy, header: "wgr.h".} = object
    hit*: bool
    handle*: WgrHandle
    distance*: cfloat
    point_local*, point_world*: CVec3
    normal_local*, normal_world*: CVec3

  # wgrender passes asset paths as `const char*`; Nim's cstring is `char*`, and clang
  # (emcc) rejects the mismatched callback type. Convert with `cstring(path)`.
  WgrConstCstring* {.importc: "const char*", nodecl.} = distinct cstring
  WgrAssetCallback* = proc (path: WgrConstCstring; user: pointer) {.cdecl.}
  WgrLifecycleFn* = proc (user: pointer) {.cdecl.}
  WgrFrameFn* = proc (dt, tickFraction: cfloat; user: pointer) {.cdecl.}

const
  WGR_WINDOW_FLAG_WINDOW_RESIZABLE* = 0x00000004'u32
  WGR_WINDOW_FLAG_MSAA_4X_HINT* = 0x00000020'u32

  WGR_LOGGER_LEVEL_WARN* = 3.cint
  WGR_LOGGER_LEVEL_ERROR* = 4.cint

  WGR_ASSET_NONE* = 0'u32
  WGR_ASSET_ADD_TAWGR_OK* = 0.cint

  WGR_CAMERA3D_PERSPECTIVE* = 0.cint
  WGR_LIGHT_DIRECTIONAL* = 0.cint
  WGR_SPRITE3D_FACING_FREE* = 3.cint

  WGR_COLOR_WHITE*    = 0xFFFFFFFF'u32
  WGR_COLOR_BLACK*    = 0x000000FF'u32
  WGR_COLOR_BLUE*     = 0x0079F1FF'u32
  WGR_COLOR_RAYWHITE* = 0xF5F5F5FF'u32

{.push importc, cdecl, header: "wgr.h".}

# lifecycle
proc wgr_init_values*(width, height: cint; title: cstring; flags: cuint): cint
proc wgr_set_init*(fn: WgrLifecycleFn; user: pointer)
proc wgr_set_frame*(fn: WgrFrameFn; user: pointer)
proc wgr_run*(): cint
proc wgr_get_platform*(): cstring
proc wgr_set_target_fps*(fps: cint)
proc wgr_request_quit*()

# logging
proc wgr_logger_set_level*(level: cint)
proc wgr_logger_message*(level: cint; format: cstring) {.varargs.}

# assets
proc wgr_asset_set_host*(host: cstring)
proc wgr_asset_ensure_async*(path, fetchUrl: cstring; flags: cuint): WgrHandle
proc wgr_asset_add_task*(task: WgrHandle; onSuccess, onFailure: WgrAssetCallback;
                        user: pointer): cint

# colors
proc wgr_color_rgba*(r, g, b, a: cint): WgrColor

# audio / sound
proc wgr_audio_create*(path: cstring): WgrHandle
proc wgr_audio_release*(audio: WgrHandle)
proc wgr_sound_create*(audio: WgrHandle): WgrHandle
proc wgr_sound_set_loop*(sound: WgrHandle; loop: bool): bool
proc wgr_sound_play*(sound: WgrHandle): bool

# mesh / model
proc wgr_mesh_create*(path: cstring): WgrHandle
proc wgr_mesh_release*(mesh: WgrHandle)
proc wgr_model_create*(mesh: WgrHandle): WgrHandle
proc wgr_model_set_animation*(model: WgrHandle; index: cint): bool
proc wgr_model_set_animation_speed*(model: WgrHandle; speed: cfloat): bool
proc wgr_model_set_animation_loop*(model: WgrHandle; loop: bool): bool
proc wgr_model_set_transform*(model: WgrHandle; px, py, pz, rx, ry, rz, sx, sy, sz: cfloat): bool
proc wgr_model_set_tint*(model: WgrHandle; color: WgrColor): bool
proc wgr_model_animate*(model: WgrHandle; dt: cfloat): bool

# texture / sprite3d
proc wgr_texture_create*(path: cstring): WgrHandle
proc wgr_texture_release*(texture: WgrHandle)
proc wgr_sprite3d_create*(texture: WgrHandle): WgrHandle
proc wgr_sprite3d_set_facing*(sprite: WgrHandle; facing: cint): bool
proc wgr_sprite3d_set_transform*(sprite: WgrHandle; px, py, pz, rx, ry, rz, sx, sy, sz: cfloat): bool
proc wgr_sprite3d_set_tint*(sprite: WgrHandle; color: WgrColor): bool
proc wgr_sprite3d_destroy*(sprite: WgrHandle)

# fonts / text
proc wgr_font_create*(path: cstring): WgrHandle
proc wgr_text_draw*(text: cstring; x, y, size: cint; color: WgrColor)
proc wgr_text_draw_ex*(font: WgrHandle; text: cstring; x, y, size: cfloat; color: WgrColor)
proc wgr_text_measure*(text: cstring; size: cint): cint
proc wgr_text_measure_ex*(font: WgrHandle; text: cstring; size: cfloat): CVec2
proc wgr_text_draw_fps_ex*(font: WgrHandle; x, y, size: cfloat; color: WgrColor)

# camera / light / scene
proc wgr_camera3d_create*(projection: cint): WgrHandle
proc wgr_camera3d_set_view*(camera: WgrHandle; px, py, pz, tx, ty, tz, ux, uy, uz: cfloat): bool
proc wgr_light_create*(kind: cint): WgrHandle
proc wgr_light_set_direction*(light: WgrHandle; x, y, z: cfloat): bool
proc wgr_light_set_intensity*(light: WgrHandle; intensity: cfloat): bool
proc wgr_scene_create*(): WgrHandle
proc wgr_scene_set_active_camera*(scene, camera: WgrHandle)
proc wgr_scene_add*(scene, drawable: WgrHandle; layer: cint): bool
proc wgr_scene_set_ambient*(scene: WgrHandle; color: WgrColor; intensity: cfloat): bool
proc wgr_scene_draw*(scene: WgrHandle)
proc wgr_scene_pick*(scene, camera: WgrHandle; mouseX, mouseY: cfloat): CPickResult

# frame
proc wgr_render_begin*()
proc wgr_render_end*()
proc wgr_render_clear_background*(color: WgrColor)
proc wgr_window_get_screen_size*(): CVec2
proc wgr_input_get_mouse_state*(): CMouseState
proc wgr_input_get_key*(key: cint): cint ## WGR_BUTTON_*; WGR_BUTTON_UP for an unknown key
proc wgr_input_get_keyboard_state*(): CKeyboardState

{.pop.}
