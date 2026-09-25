## wgr_sprite3d.h, wrapped.

import ./types, ./internal/convert, ./raw

proc newSprite3d*(texture: Texture): Sprite3d = Sprite3d(wgr_sprite3d_create(texture.cHandle))

proc newSprite3d*(): Sprite3d = Sprite3d(wgr_sprite3d_create(0)) ## its texture set later (setTexture)

proc setFacing*(sprite: Sprite3d; facing: SpriteFacing): bool {.discardable.} =
  wgr_sprite3d_set_facing(sprite.cHandle, ord(facing).cint)

proc setTransform*(sprite: Sprite3d; position, rotation, scale: Vec3): bool {.discardable.} =
  ## position, rotation (radians) and scale in one call: the cheapest way to move it every frame
  wgr_sprite3d_set_transform(sprite.cHandle, position.x, position.y, position.z,
                            rotation.x, rotation.y, rotation.z, scale.x, scale.y, scale.z)

proc setPosition*(sprite: Sprite3d; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are
  wgr_sprite3d_set_position(sprite.cHandle, value.x, value.y, value.z)

proc setPosition*(sprite: Sprite3d; x, y, z: float): bool {.discardable.} =
  wgr_sprite3d_set_position(sprite.cHandle, x, y, z)

proc setRotation*(sprite: Sprite3d; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are (radians)
  wgr_sprite3d_set_rotation(sprite.cHandle, value.x, value.y, value.z)

proc setRotation*(sprite: Sprite3d; x, y, z: float): bool {.discardable.} =
  wgr_sprite3d_set_rotation(sprite.cHandle, x, y, z)

proc setScale*(sprite: Sprite3d; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are
  wgr_sprite3d_set_scale(sprite.cHandle, value.x, value.y, value.z)

proc setScale*(sprite: Sprite3d; x, y, z: float): bool {.discardable.} =
  wgr_sprite3d_set_scale(sprite.cHandle, x, y, z)

proc getPosition*(sprite: Sprite3d): Vec3 = wgr_sprite3d_get_position(sprite.cHandle).toNim

proc getRotation*(sprite: Sprite3d): Vec3 = wgr_sprite3d_get_rotation(sprite.cHandle).toNim

proc getScale*(sprite: Sprite3d): Vec3 = wgr_sprite3d_get_scale(sprite.cHandle).toNim

proc setTint*(sprite: Sprite3d; color: Color): bool {.discardable.} =
  wgr_sprite3d_set_tint(sprite.cHandle, color)

proc destroy*(sprite: Sprite3d) = wgr_sprite3d_destroy(sprite.cHandle)

proc setTexture*(sprite: Sprite3d; texture: Texture): bool {.discardable.} =
  wgr_sprite3d_set_texture(sprite.cHandle, texture.cHandle)

proc setSize*(sprite: Sprite3d; size: float): bool {.discardable.} =
  ## its larger side, in world units, the other kept in proportion
  wgr_sprite3d_set_size(sprite.cHandle, size.cfloat)

proc setExtent*(sprite: Sprite3d; width, height: float): bool {.discardable.} =
  ## width and height in world units
  wgr_sprite3d_set_extent(sprite.cHandle, width.cfloat, height.cfloat)

proc setSource*(sprite: Sprite3d; x, y, width, height: float): bool {.discardable.} =
  wgr_sprite3d_set_source(sprite.cHandle, x.cfloat, y.cfloat, width.cfloat, height.cfloat)

proc setPivot*(sprite: Sprite3d; x, y: float): bool {.discardable.} =
  wgr_sprite3d_set_pivot(sprite.cHandle, x.cfloat, y.cfloat)

proc setVisible*(sprite: Sprite3d; visible: bool): bool {.discardable.} = wgr_sprite3d_set_visible(sprite.cHandle, visible)

proc isVisible*(sprite: Sprite3d): bool = wgr_sprite3d_is_visible(sprite.cHandle)

proc setPickable*(sprite: Sprite3d; pickable: bool): bool {.discardable.} =
  wgr_sprite3d_set_pickable(sprite.cHandle, pickable)

proc isPickable*(sprite: Sprite3d): bool = wgr_sprite3d_is_pickable(sprite.cHandle)

proc setEnabled*(sprite: Sprite3d; enabled: bool): bool {.discardable.} = wgr_sprite3d_set_enabled(sprite.cHandle, enabled)

proc isEnabled*(sprite: Sprite3d): bool = wgr_sprite3d_is_enabled(sprite.cHandle)

proc setAlphaMode*(sprite: Sprite3d; mode: AlphaMode; cutoff = 0.5): bool {.discardable.} =
  wgr_sprite3d_set_alpha_mode(sprite.cHandle, ord(mode).cint, cutoff.cfloat)

proc getAlphaMode*(sprite: Sprite3d): AlphaMode = AlphaMode(wgr_sprite3d_get_alpha_mode(sprite.cHandle))

proc setMaterial*(sprite: Sprite3d; material: Material): bool {.discardable.} =
  ## lit by a material instead of drawn unlit
  wgr_sprite3d_set_material(sprite.cHandle, material.cHandle)

proc getMaterial*(sprite: Sprite3d): Material = Material(wgr_sprite3d_get_material(sprite.cHandle))

proc setPickAlphaTest*(sprite: Sprite3d; enable: bool; threshold = 0.5): bool {.discardable.} =
  wgr_sprite3d_set_pick_alpha_test(sprite.cHandle, enable, threshold.cfloat)

proc draw*(sprite: Sprite3d) = wgr_sprite3d_draw(sprite.cHandle) ## immediate, in 3D mode
