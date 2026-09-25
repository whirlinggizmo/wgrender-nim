## wgr_model.h, wrapped.

import ./types, ./internal/convert, ./raw

proc release*(mesh: Mesh) = wgr_mesh_release(mesh.cHandle)

proc newModel*(mesh: Mesh): Model = Model(wgr_model_create(mesh.cHandle))

proc newModel*(): Model = Model(wgr_model_create(0)) ## its mesh set later (setMesh)

proc setAnimation*(model: Model; index: int): bool {.discardable.} =
  wgr_model_set_animation(model.cHandle, index.cint)

proc setAnimationSpeed*(model: Model; speed: float): bool {.discardable.} =
  wgr_model_set_animation_speed(model.cHandle, speed.cfloat)

proc setAnimationLoop*(model: Model; loop: bool): bool {.discardable.} =
  wgr_model_set_animation_loop(model.cHandle, loop)

proc setTransform*(model: Model; position, rotation, scale: Vec3): bool {.discardable.} =
  ## position, rotation (radians) and scale in one call: the cheapest way to move it every frame
  wgr_model_set_transform(model.cHandle, position.x, position.y, position.z,
                         rotation.x, rotation.y, rotation.z, scale.x, scale.y, scale.z)

proc setPosition*(model: Model; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are
  wgr_model_set_position(model.cHandle, value.x, value.y, value.z)

proc setPosition*(model: Model; x, y, z: float): bool {.discardable.} =
  wgr_model_set_position(model.cHandle, x, y, z)

proc setRotation*(model: Model; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are (radians)
  wgr_model_set_rotation(model.cHandle, value.x, value.y, value.z)

proc setRotation*(model: Model; x, y, z: float): bool {.discardable.} =
  wgr_model_set_rotation(model.cHandle, x, y, z)

proc setScale*(model: Model; value: Vec3): bool {.discardable.} =
  ## one part of the transform, leaving the others as they are
  wgr_model_set_scale(model.cHandle, value.x, value.y, value.z)

proc setScale*(model: Model; x, y, z: float): bool {.discardable.} =
  wgr_model_set_scale(model.cHandle, x, y, z)

proc getPosition*(model: Model): Vec3 = wgr_model_get_position(model.cHandle).toNim

proc getRotation*(model: Model): Vec3 = wgr_model_get_rotation(model.cHandle).toNim

proc getScale*(model: Model): Vec3 = wgr_model_get_scale(model.cHandle).toNim

proc setTint*(model: Model; color: Color): bool {.discardable.} = wgr_model_set_tint(model.cHandle, color)

proc animate*(model: Model; dt: float): bool {.discardable.} = wgr_model_animate(model.cHandle, dt.cfloat)

proc newMeshPlane*(width, length: float; subdivisions = 0): Mesh =
  ## flat in XZ facing +Y; `subdivisions` 0..256 adds that many cells each way
  Mesh(wgr_mesh_create_plane(width.cfloat, length.cfloat, subdivisions.cint))

proc newMeshCube*(width, height, length: float): Mesh =
  ## each face its own vertices, so the edges stay sharp; textured 0..1 per face
  Mesh(wgr_mesh_create_cube(width.cfloat, height.cfloat, length.cfloat))

proc newMeshSphere*(radius: float; rings = 16; segments = 32): Mesh =
  ## `rings` 2..256 pole to pole, `segments` 3..512 around
  Mesh(wgr_mesh_create_sphere(radius.cfloat, rings.cint, segments.cint))

proc newMeshCylinder*(radius, height: float; segments = 32): Mesh =
  ## capped; `segments` 3..512 around
  Mesh(wgr_mesh_create_cylinder(radius.cfloat, height.cfloat, segments.cint))

proc newMeshCone*(radius, height: float; segments = 32): Mesh =
  ## tip up, capped base
  Mesh(wgr_mesh_create_cone(radius.cfloat, height.cfloat, segments.cint))

proc newMeshCapsule*(radius, height: float; rings = 8; segments = 32): Mesh =
  ## `height` is end to end, at least twice `radius`; less than that gives a sphere
  Mesh(wgr_mesh_create_capsule(radius.cfloat, height.cfloat, rings.cint, segments.cint))

proc newMeshTorus*(radius, thickness: float; rings = 16; segments = 32): Mesh =
  ## around y: `radius` reaches the middle of the tube, `thickness` is its radius
  Mesh(wgr_mesh_create_torus(radius.cfloat, thickness.cfloat, rings.cint, segments.cint))

proc getMaterialCount*(mesh: Mesh): int = wgr_mesh_get_material_count(mesh.cHandle).int

proc getMaterial*(mesh: Mesh; slot: int): Material = Material(wgr_mesh_get_material(mesh.cHandle, slot.cint))

proc setMesh*(model: Model; mesh: Mesh): bool {.discardable.} = wgr_model_set_mesh(model.cHandle, mesh.cHandle)

proc setMaterial*(model: Model; slot: int; material: Material): bool {.discardable.} =
  ## this model's own material for a slot of its mesh, over the mesh's
  wgr_model_set_material(model.cHandle, slot.cint, material.cHandle)

proc getMaterial*(model: Model; slot: int): Material = Material(wgr_model_get_material(model.cHandle, slot.cint))

proc setVisible*(model: Model; visible: bool): bool {.discardable.} = wgr_model_set_visible(model.cHandle, visible)

proc isVisible*(model: Model): bool = wgr_model_is_visible(model.cHandle)

proc setPickable*(model: Model; pickable: bool): bool {.discardable.} = wgr_model_set_pickable(model.cHandle, pickable)

proc isPickable*(model: Model): bool = wgr_model_is_pickable(model.cHandle)

proc setEnabled*(model: Model; enabled: bool): bool {.discardable.} = wgr_model_set_enabled(model.cHandle, enabled)

proc isEnabled*(model: Model): bool = wgr_model_is_enabled(model.cHandle)

proc setCastsShadow*(model: Model; casts: bool): bool {.discardable.} = wgr_model_set_casts_shadow(model.cHandle, casts)

proc castsShadow*(model: Model): bool = wgr_model_casts_shadow(model.cHandle)

proc setReceivesShadow*(model: Model; receives: bool): bool {.discardable.} =
  wgr_model_set_receives_shadow(model.cHandle, receives)

proc receivesShadow*(model: Model): bool = wgr_model_receives_shadow(model.cHandle)

proc draw*(model: Model) =
  ## immediate, in 3D mode, for one not in a scene: unlit (base color x tint)
  wgr_model_draw(model.cHandle)

proc destroy*(model: Model) = wgr_model_destroy(model.cHandle)

proc getAnimationCount*(model: Model): int = wgr_model_get_animation_count(model.cHandle).int

proc setAnimationTime*(model: Model; seconds: float): bool {.discardable.} =
  wgr_model_set_animation_time(model.cHandle, seconds.cfloat)

proc getAnimationTime*(model: Model): float = wgr_model_get_animation_time(model.cHandle).float

proc getAnimationDuration*(model: Model; animation: int): float =
  wgr_model_get_animation_duration(model.cHandle, animation.cint).float

proc isReady*(model: Model): bool = wgr_model_is_ready(model.cHandle) ## its mesh has loaded
