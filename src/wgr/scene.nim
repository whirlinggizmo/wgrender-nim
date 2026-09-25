## wgr_scene.h, wrapped.

import ./types, ./internal/convert, ./raw

proc newScene*(): Scene = Scene(wgr_scene_create())

proc setActiveCamera*(scene: Scene; camera: Camera3d) =
  wgr_scene_set_active_camera(scene.cHandle, camera.cHandle)

proc setAmbient*(scene: Scene; color: Color; intensity: float): bool {.discardable.} =
  wgr_scene_set_ambient(scene.cHandle, color, intensity.cfloat)

proc draw*(scene: Scene) = wgr_scene_draw(scene.cHandle)

proc destroy*(scene: Scene) = wgr_scene_destroy(scene.cHandle)

proc setLayer*(scene: Scene; member: SceneMember; layer: int): bool {.discardable.} =
  wgr_scene_set_layer(scene.cHandle, member.cHandle, layer.cint)

proc remove*(scene: Scene; member: SceneMember): bool {.discardable.} = wgr_scene_remove(scene.cHandle, member.cHandle)

proc clear*(scene: Scene) = wgr_scene_clear(scene.cHandle) ## every member out

proc setClip*(scene: Scene; layer: int; rect: Rect): bool {.discardable.} =
  ## a 2D layer drawn only inside `rect` (width or height 0: no clip)
  wgr_scene_set_clip(scene.cHandle, layer.cint, rect.x, rect.y, rect.width, rect.height)

proc setEnvironment*(scene: Scene; environment: Environment; intensity = 1.0;
                     rotation = 0.0): bool {.discardable.} =
  ## image-based light from it, turned `rotation` radians about y
  wgr_scene_set_environment(scene.cHandle, environment.cHandle, intensity.cfloat, rotation.cfloat)

proc setBackground*(scene: Scene; environment: Environment; blur = 0.0): bool {.discardable.} =
  ## drawn behind everything, blurred by 0 .. 1
  wgr_scene_set_background(scene.cHandle, environment.cHandle, blur.cfloat)

proc setInteractive*(scene: Scene; interactive: bool): bool {.discardable.} =
  ## whether it tracks hover, press and click (getHover, isClicked)
  wgr_scene_set_interactive(scene.cHandle, interactive)

proc isInteractive*(scene: Scene): bool = wgr_scene_is_interactive(scene.cHandle)

proc setCulling*(scene: Scene; culling: bool): bool {.discardable.} = wgr_scene_set_culling(scene.cHandle, culling)

proc isCulling*(scene: Scene): bool = wgr_scene_is_culling(scene.cHandle)

proc getHovered*(scene: Scene): Handle = Handle(wgr_scene_get_hovered(scene.cHandle)) ## what the pointer is over

proc getHover*(scene: Scene; member: SceneMember): ButtonState =
  ## Pressed the frame the pointer comes over it, Down while it stays, Released when it leaves
  ButtonState(wgr_scene_get_hover(scene.cHandle, member.cHandle))

proc getPress*(scene: Scene; member: SceneMember): ButtonState =
  ButtonState(wgr_scene_get_press(scene.cHandle, member.cHandle))

proc isClicked*(scene: Scene; member: SceneMember): bool =
  ## pressed and released on it, this frame
  wgr_scene_is_clicked(scene.cHandle, member.cHandle)

proc pick*(scene: Scene; x, y: float; camera = Camera3d(0)): PickResult =
  ## camera none: the scene's active camera. Compare `handle` with typed handles:
  ## `pick.handle == model`.
  let r = wgr_scene_pick(scene.cHandle, camera.cHandle, x.cfloat, y.cfloat)
  PickResult(hit: r.hit, handle: Handle(r.handle), distance: r.distance.float,
             pointLocal: r.point_local.toNim, pointWorld: r.point_world.toNim,
             normalLocal: r.normal_local.toNim, normalWorld: r.normal_world.toNim)
