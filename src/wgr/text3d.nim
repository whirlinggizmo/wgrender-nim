## wgr_text3d.h, wrapped.

import ./types, ./internal/convert, ./raw

proc drawText*(font: Font; text: string; position: Vec3; size: float; color: Color) =
  ## in the world, facing the camera, in 3D mode (for text that stays, Text3d)
  wgr_text_draw_3d(font.cHandle, text.cstring, position.x, position.y, position.z, size.cfloat, color)

proc newText3d*(font: Font): Text3d =
  ## font none: the default font (setDefaultFont)
  Text3d(wgr_text3d_create(font.cHandle))
proc destroy*(text: Text3d) = wgr_text3d_destroy(text.cHandle)
proc setFont*(text: Text3d; font: Font): bool {.discardable.} = wgr_text3d_set_font(text.cHandle, font.cHandle)
proc setText*(text: Text3d; value: string): bool {.discardable.} = wgr_text3d_set_text(text.cHandle, value.cstring)
proc setSize*(text: Text3d; size: float): bool {.discardable.} =
  ## line height, world units
  wgr_text3d_set_size(text.cHandle, size.cfloat)
proc setAlign*(text: Text3d; horizontal: AlignX; vertical: AlignY): bool {.discardable.} =
  ## where the block sits relative to its position
  wgr_text3d_set_align(text.cHandle, ord(horizontal).cint, ord(vertical).cint)
proc setMaxWidth*(text: Text3d; width: float): bool {.discardable.} =
  ## wraps at this width, world units (0: no wrapping)
  wgr_text3d_set_max_width(text.cHandle, width.cfloat)
proc setTransform*(text: Text3d; position, rotation: Vec3): bool {.discardable.} =
  wgr_text3d_set_transform(text.cHandle, position.x, position.y, position.z, rotation.x, rotation.y, rotation.z)
proc setPosition*(text: Text3d; value: Vec3): bool {.discardable.} =
  wgr_text3d_set_position(text.cHandle, value.x, value.y, value.z)
proc setPosition*(text: Text3d; x, y, z: float): bool {.discardable.} = wgr_text3d_set_position(text.cHandle, x, y, z)
proc setRotation*(text: Text3d; value: Vec3): bool {.discardable.} =
  ## radians; only with SpriteFacing.Free
  wgr_text3d_set_rotation(text.cHandle, value.x, value.y, value.z)
proc getPosition*(text: Text3d): Vec3 = wgr_text3d_get_position(text.cHandle).toNim
proc getRotation*(text: Text3d): Vec3 = wgr_text3d_get_rotation(text.cHandle).toNim
proc setFacing*(text: Text3d; facing: SpriteFacing): bool {.discardable.} =
  ## toward the camera (the default), upright, flat facing up, or by its rotation
  wgr_text3d_set_facing(text.cHandle, ord(facing).cint)
proc setColor*(text: Text3d; color: Color): bool {.discardable.} = wgr_text3d_set_color(text.cHandle, color)
proc setVisible*(text: Text3d; visible: bool): bool {.discardable.} = wgr_text3d_set_visible(text.cHandle, visible)
proc isVisible*(text: Text3d): bool = wgr_text3d_is_visible(text.cHandle)
proc setPickable*(text: Text3d; pickable: bool): bool {.discardable.} =
  wgr_text3d_set_pickable(text.cHandle, pickable)
proc isPickable*(text: Text3d): bool = wgr_text3d_is_pickable(text.cHandle)
proc setEnabled*(text: Text3d; enabled: bool): bool {.discardable.} = wgr_text3d_set_enabled(text.cHandle, enabled)
proc isEnabled*(text: Text3d): bool = wgr_text3d_is_enabled(text.cHandle)
proc getSize*(text: Text3d): Vec2 =
  ## the laid-out block's width and height, world units
  wgr_text3d_get_size(text.cHandle).toNim
proc draw*(text: Text3d) = wgr_text3d_draw(text.cHandle) ## immediate, in 3D mode
