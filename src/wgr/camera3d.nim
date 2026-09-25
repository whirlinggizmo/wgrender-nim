## wgr_camera3d.h, wrapped.

import ./types, ./internal/convert, ./raw

proc newCamera3d*(projection = Projection.Perspective): Camera3d =
  Camera3d(wgr_camera3d_create(ord(projection).cint))

proc setView*(camera: Camera3d; position, target: Vec3;
              up: Vec3 = (0.0, 1.0, 0.0)): bool {.discardable.} =
  wgr_camera3d_set_view(camera.cHandle, position.x, position.y, position.z,
                       target.x, target.y, target.z, up.x, up.y, up.z)

proc destroy*(camera: Camera3d) = wgr_camera3d_destroy(camera.cHandle)

proc getDefaultCamera3d*(): Camera3d =
  ## the one drawing uses when none is set active: at (0, 0, 10) looking at the origin
  Camera3d(wgr_camera3d_get_default())

proc setActive*(camera: Camera3d): bool {.discardable.} =
  ## what immediate 3D drawing (beginMode3d) goes through
  wgr_camera3d_set_active(camera.cHandle)

proc getActiveCamera3d*(): Camera3d = Camera3d(wgr_camera3d_get_active())

proc setProjection*(camera: Camera3d; projection: Projection): bool {.discardable.} =
  wgr_camera3d_set_projection(camera.cHandle, ord(projection).cint)

proc getProjection*(camera: Camera3d): Projection = Projection(wgr_camera3d_get_projection(camera.cHandle))

proc setFov*(camera: Camera3d; fov: float): bool {.discardable.} =
  ## the perspective's vertical field of view, radians (default pi/4)
  wgr_camera3d_set_fov(camera.cHandle, fov.cfloat)

proc getFov*(camera: Camera3d): float = wgr_camera3d_get_fov(camera.cHandle).float

proc setOrthoHeight*(camera: Camera3d; height: float): bool {.discardable.} =
  ## how much of the world an orthographic view shows top to bottom (default 10)
  wgr_camera3d_set_ortho_height(camera.cHandle, height.cfloat)

proc getOrthoHeight*(camera: Camera3d): float = wgr_camera3d_get_ortho_height(camera.cHandle).float
