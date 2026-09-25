## wgr_shape2d.h, wrapped.

import ./types, ./internal/convert, ./raw

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

# Retained: Shape2d objects a scene holds (2D members draw over all 3D), or draw directly.

proc newShape2d*(): Shape2d = Shape2d(wgr_shape2d_create())
proc destroy*(shape: Shape2d) = wgr_shape2d_destroy(shape.cHandle)
proc setRectangle*(shape: Shape2d; width, height: float; cornerRadius = 0.0): bool {.discardable.} =
  ## from its origin (top-left) to (width, height)
  wgr_shape2d_set_rectangle(shape.cHandle, width.cfloat, height.cfloat, cornerRadius.cfloat)
proc setCircle*(shape: Shape2d; radius: float): bool {.discardable.} =
  ## centered on its origin
  wgr_shape2d_set_circle(shape.cHandle, radius.cfloat)
proc setLine*(shape: Shape2d; start, finish: Vec2; thickness: float): bool {.discardable.} =
  wgr_shape2d_set_line(shape.cHandle, start.x, start.y, finish.x, finish.y, thickness.cfloat)
proc setTransform*(shape: Shape2d; position: Vec2; rotation: float; scale: Vec2): bool {.discardable.} =
  wgr_shape2d_set_transform(shape.cHandle, position.x, position.y, rotation, scale.x, scale.y)
proc setPosition*(shape: Shape2d; value: Vec2): bool {.discardable.} =
  ## where the pivot goes
  wgr_shape2d_set_position(shape.cHandle, value.x, value.y)
proc setPosition*(shape: Shape2d; x, y: float): bool {.discardable.} = wgr_shape2d_set_position(shape.cHandle, x, y)
proc setRotation*(shape: Shape2d; angle: float): bool {.discardable.} =
  ## radians, around the pivot
  wgr_shape2d_set_rotation(shape.cHandle, angle.cfloat)
proc setScale*(shape: Shape2d; value: Vec2): bool {.discardable.} = wgr_shape2d_set_scale(shape.cHandle, value.x, value.y)
proc getPosition*(shape: Shape2d): Vec2 = wgr_shape2d_get_position(shape.cHandle).toNim
proc getRotation*(shape: Shape2d): float = wgr_shape2d_get_rotation(shape.cHandle).float
proc getScale*(shape: Shape2d): Vec2 = wgr_shape2d_get_scale(shape.cHandle).toNim
proc setPivot*(shape: Shape2d; x, y: float): bool {.discardable.} =
  ## as a fraction of its bounds: (0, 0) top-left, (0.5, 0.5) the middle
  wgr_shape2d_set_pivot(shape.cHandle, x.cfloat, y.cfloat)
proc setOutline*(shape: Shape2d; thickness: float): bool {.discardable.} =
  ## drawn as an outline this thick (0: filled)
  wgr_shape2d_set_outline(shape.cHandle, thickness.cfloat)
proc setColor*(shape: Shape2d; color: Color): bool {.discardable.} = wgr_shape2d_set_color(shape.cHandle, color)
proc setVisible*(shape: Shape2d; visible: bool): bool {.discardable.} = wgr_shape2d_set_visible(shape.cHandle, visible)
proc isVisible*(shape: Shape2d): bool = wgr_shape2d_is_visible(shape.cHandle)
proc setPickable*(shape: Shape2d; pickable: bool): bool {.discardable.} =
  wgr_shape2d_set_pickable(shape.cHandle, pickable)
proc isPickable*(shape: Shape2d): bool = wgr_shape2d_is_pickable(shape.cHandle)
proc setEnabled*(shape: Shape2d; enabled: bool): bool {.discardable.} = wgr_shape2d_set_enabled(shape.cHandle, enabled)
proc isEnabled*(shape: Shape2d): bool = wgr_shape2d_is_enabled(shape.cHandle)
proc draw*(shape: Shape2d) = wgr_shape2d_draw(shape.cHandle) ## immediate, for one not in a scene
