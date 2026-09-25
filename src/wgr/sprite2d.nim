## wgr_sprite2d.h, wrapped.

import ./types, ./internal/convert, ./raw

proc newSprite2d*(texture: Texture): Sprite2d = Sprite2d(wgr_sprite2d_create(texture.cHandle))

proc destroy*(sprite: Sprite2d) = wgr_sprite2d_destroy(sprite.cHandle)

proc setTexture*(sprite: Sprite2d; texture: Texture): bool {.discardable.} =
  wgr_sprite2d_set_texture(sprite.cHandle, texture.cHandle)

proc setSource*(sprite: Sprite2d; x, y, width, height: float): bool {.discardable.} =
  ## the region of the texture it shows, in texture pixels
  wgr_sprite2d_set_source(sprite.cHandle, x.cfloat, y.cfloat, width.cfloat, height.cfloat)

proc setTransform*(sprite: Sprite2d; position: Vec2; rotation: float; scale: Vec2): bool {.discardable.} =
  ## position, rotation (radians, around the pivot) and scale in one call
  wgr_sprite2d_set_transform(sprite.cHandle, position.x, position.y, rotation, scale.x, scale.y)

proc setPosition*(sprite: Sprite2d; value: Vec2): bool {.discardable.} =
  ## where the pivot goes
  wgr_sprite2d_set_position(sprite.cHandle, value.x, value.y)

proc setPosition*(sprite: Sprite2d; x, y: float): bool {.discardable.} =
  wgr_sprite2d_set_position(sprite.cHandle, x, y)

proc setRotation*(sprite: Sprite2d; angle: float): bool {.discardable.} =
  ## radians, around the pivot
  wgr_sprite2d_set_rotation(sprite.cHandle, angle.cfloat)

proc setScale*(sprite: Sprite2d; value: Vec2): bool {.discardable.} =
  wgr_sprite2d_set_scale(sprite.cHandle, value.x, value.y)

proc setScale*(sprite: Sprite2d; x, y: float): bool {.discardable.} =
  wgr_sprite2d_set_scale(sprite.cHandle, x, y)

proc getPosition*(sprite: Sprite2d): Vec2 = wgr_sprite2d_get_position(sprite.cHandle).toNim

proc getRotation*(sprite: Sprite2d): float = wgr_sprite2d_get_rotation(sprite.cHandle).float

proc getScale*(sprite: Sprite2d): Vec2 = wgr_sprite2d_get_scale(sprite.cHandle).toNim

proc setSize*(sprite: Sprite2d; width, height: float): bool {.discardable.} =
  ## drawn at this size, in pixels (default the source's)
  wgr_sprite2d_set_size(sprite.cHandle, width.cfloat, height.cfloat)

proc setPivot*(sprite: Sprite2d; x, y: float): bool {.discardable.} =
  ## the point the position refers to, as a fraction of its size (0.5, 0.5: the middle)
  wgr_sprite2d_set_pivot(sprite.cHandle, x.cfloat, y.cfloat)

proc setNineSlice*(sprite: Sprite2d; left, top, right, bottom: float): bool {.discardable.} =
  ## the source's borders kept at their size when it's drawn larger (0s: off)
  wgr_sprite2d_set_nine_slice(sprite.cHandle, left.cfloat, top.cfloat, right.cfloat, bottom.cfloat)

proc setTint*(sprite: Sprite2d; color: Color): bool {.discardable.} = wgr_sprite2d_set_tint(sprite.cHandle, color)

proc setVisible*(sprite: Sprite2d; visible: bool): bool {.discardable.} =
  wgr_sprite2d_set_visible(sprite.cHandle, visible)

proc isVisible*(sprite: Sprite2d): bool = wgr_sprite2d_is_visible(sprite.cHandle)

proc setPickable*(sprite: Sprite2d; pickable: bool): bool {.discardable.} =
  wgr_sprite2d_set_pickable(sprite.cHandle, pickable)

proc isPickable*(sprite: Sprite2d): bool = wgr_sprite2d_is_pickable(sprite.cHandle)

proc setEnabled*(sprite: Sprite2d; enabled: bool): bool {.discardable.} =
  wgr_sprite2d_set_enabled(sprite.cHandle, enabled)

proc isEnabled*(sprite: Sprite2d): bool = wgr_sprite2d_is_enabled(sprite.cHandle)

proc setAlphaMode*(sprite: Sprite2d; mode: AlphaMode; cutoff = 0.5): bool {.discardable.} =
  wgr_sprite2d_set_alpha_mode(sprite.cHandle, ord(mode).cint, cutoff.cfloat)

proc getAlphaMode*(sprite: Sprite2d): AlphaMode = AlphaMode(wgr_sprite2d_get_alpha_mode(sprite.cHandle))

proc setPickAlphaTest*(sprite: Sprite2d; enable: bool; threshold = 0.5): bool {.discardable.} =
  ## picked only where its texture's alpha is above `threshold`
  wgr_sprite2d_set_pick_alpha_test(sprite.cHandle, enable, threshold.cfloat)

proc setMaterial*(sprite: Sprite2d; material: Material): bool {.discardable.} =
  wgr_sprite2d_set_material(sprite.cHandle, material.cHandle)

proc getMaterial*(sprite: Sprite2d): Material = Material(wgr_sprite2d_get_material(sprite.cHandle))

proc draw*(sprite: Sprite2d) = wgr_sprite2d_draw(sprite.cHandle) ## immediate, for one not in a scene
