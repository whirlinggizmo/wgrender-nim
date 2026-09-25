## wgr_shape3d.h, wrapped.

import ./types, ./internal/convert, ./raw

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

proc destroy*(shape: Shape3d) = wgr_shape3d_destroy(shape.cHandle)

proc setCube*(shape: Shape3d; size: Vec3): bool {.discardable.} =
  wgr_shape3d_set_cube(shape.cHandle, size.x, size.y, size.z)

proc setSphere*(shape: Shape3d; radius: float): bool {.discardable.} =
  wgr_shape3d_set_sphere(shape.cHandle, radius.cfloat)

proc setRectangle*(shape: Shape3d; width, height: float): bool {.discardable.} =
  wgr_shape3d_set_rectangle(shape.cHandle, width.cfloat, height.cfloat)

proc setCircle*(shape: Shape3d; radius: float): bool {.discardable.} =
  wgr_shape3d_set_circle(shape.cHandle, radius.cfloat)

proc setLine*(shape: Shape3d; start, finish: Vec3): bool {.discardable.} =
  wgr_shape3d_set_line(shape.cHandle, start.x, start.y, start.z, finish.x, finish.y, finish.z)

proc setLineStrip*(shape: Shape3d): bool {.discardable.} =
  ## a line through the points addPoint adds
  wgr_shape3d_set_line_strip(shape.cHandle)

proc addPoint*(shape: Shape3d; point: Vec3): bool {.discardable.} =
  wgr_shape3d_add_point(shape.cHandle, point.x, point.y, point.z)

proc getPointCount*(shape: Shape3d): int = wgr_shape3d_get_point_count(shape.cHandle).int

proc setTransform*(shape: Shape3d; position, rotation, scale: Vec3): bool {.discardable.} =
  wgr_shape3d_set_transform(shape.cHandle, position.x, position.y, position.z,
                           rotation.x, rotation.y, rotation.z, scale.x, scale.y, scale.z)

proc setPosition*(shape: Shape3d; value: Vec3): bool {.discardable.} =
  wgr_shape3d_set_position(shape.cHandle, value.x, value.y, value.z)

proc setPosition*(shape: Shape3d; x, y, z: float): bool {.discardable.} =
  wgr_shape3d_set_position(shape.cHandle, x, y, z)

proc setRotation*(shape: Shape3d; value: Vec3): bool {.discardable.} =
  wgr_shape3d_set_rotation(shape.cHandle, value.x, value.y, value.z)

proc setScale*(shape: Shape3d; value: Vec3): bool {.discardable.} =
  wgr_shape3d_set_scale(shape.cHandle, value.x, value.y, value.z)

proc getPosition*(shape: Shape3d): Vec3 = wgr_shape3d_get_position(shape.cHandle).toNim

proc getRotation*(shape: Shape3d): Vec3 = wgr_shape3d_get_rotation(shape.cHandle).toNim

proc getScale*(shape: Shape3d): Vec3 = wgr_shape3d_get_scale(shape.cHandle).toNim

proc setColor*(shape: Shape3d; color: Color): bool {.discardable.} = wgr_shape3d_set_color(shape.cHandle, color)

proc setVisible*(shape: Shape3d; visible: bool): bool {.discardable.} =
  wgr_shape3d_set_visible(shape.cHandle, visible)

proc isVisible*(shape: Shape3d): bool = wgr_shape3d_is_visible(shape.cHandle)

proc setPickable*(shape: Shape3d; pickable: bool): bool {.discardable.} =
  wgr_shape3d_set_pickable(shape.cHandle, pickable)

proc isPickable*(shape: Shape3d): bool = wgr_shape3d_is_pickable(shape.cHandle)

proc setEnabled*(shape: Shape3d; enabled: bool): bool {.discardable.} =
  wgr_shape3d_set_enabled(shape.cHandle, enabled)

proc isEnabled*(shape: Shape3d): bool = wgr_shape3d_is_enabled(shape.cHandle)

proc draw*(shape: Shape3d) = wgr_shape3d_draw(shape.cHandle) ## immediate, in 3D mode, for one not in a scene

proc drawGrid*(slices: int; spacing: float; color: Color) =
  ## a grid on the ground (XZ), between beginMode3d and endMode3d
  wgr_shape3d_draw_grid(slices.cint, spacing.cfloat, color)
