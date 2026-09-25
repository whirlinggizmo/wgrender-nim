## wgr_emitter3d.h and wgr_emitter2d.h: particles, wrapped.

import ./types, ./internal/convert, ./raw

proc newEmitter3d*(texture: Texture): Emitter3d = Emitter3d(wgr_emitter3d_create(texture.cHandle))

proc destroy*(e: Emitter3d) = wgr_emitter3d_destroy(e.cHandle)

proc setSource*(e: Emitter; x, y, width, height: float): bool {.discardable.} =
  ## the region of the texture each particle shows, in texture pixels; width or height
  ## <= 0: the whole texture
  (when e is Emitter3d: wgr_emitter3d_set_source(e.cHandle, x.cfloat, y.cfloat, width.cfloat, height.cfloat)
   else: wgr_emitter2d_set_source(e.cHandle, x.cfloat, y.cfloat, width.cfloat, height.cfloat))

proc setFrames*(e: Emitter; columns, rows: int; count = 0; perSecond = 0.0): bool {.discardable.} =
  ## a flipbook: the source in columns x rows frames, the first `count` used (0: all);
  ## perSecond 0 plays them once over each particle's life, above 0 loops at that rate
  (when e is Emitter3d: wgr_emitter3d_set_frames(e.cHandle, columns.cint, rows.cint, count.cint, perSecond.cfloat)
   else: wgr_emitter2d_set_frames(e.cHandle, columns.cint, rows.cint, count.cint, perSecond.cfloat))

proc setPosition*(e: Emitter3d; value: Vec3): bool {.discardable.} =
  ## a move: the steady spawns spread along the way, and particles inherit its velocity
  wgr_emitter3d_set_position(e.cHandle, value.x, value.y, value.z)

proc setPosition*(e: Emitter3d; x, y, z: float): bool {.discardable.} =
  wgr_emitter3d_set_position(e.cHandle, x, y, z)

proc jump*(e: Emitter3d; value: Vec3): bool {.discardable.} =
  ## put it somewhere without a move: nothing spawns along the way
  wgr_emitter3d_jump(e.cHandle, value.x, value.y, value.z)

proc jump*(e: Emitter3d; x, y, z: float): bool {.discardable.} = wgr_emitter3d_jump(e.cHandle, x, y, z)

proc getPosition*(e: Emitter3d): Vec3 = wgr_emitter3d_get_position(e.cHandle).toNim

proc setRate*(e: Emitter; perSecond: float): bool {.discardable.} =
  ## the steady rate, particles per second (0: bursts only)
  (when e is Emitter3d: wgr_emitter3d_set_rate(e.cHandle, perSecond.cfloat)
   else: wgr_emitter2d_set_rate(e.cHandle, perSecond.cfloat))

proc burst*(e: Emitter; count: int): bool {.discardable.} =
  (when e is Emitter3d: wgr_emitter3d_burst(e.cHandle, count.cint)
   else: wgr_emitter2d_burst(e.cHandle, count.cint))

proc setEmitting*(e: Emitter; emitting: bool): bool {.discardable.} =
  ## false stops the steady rate; the particles alive finish their lives
  (when e is Emitter3d: wgr_emitter3d_set_emitting(e.cHandle, emitting)
   else: wgr_emitter2d_set_emitting(e.cHandle, emitting))

proc isEmitting*(e: Emitter): bool =
  (when e is Emitter3d: wgr_emitter3d_is_emitting(e.cHandle)
   else: wgr_emitter2d_is_emitting(e.cHandle))

proc setMax*(e: Emitter; count: int): bool {.discardable.} =
  ## at most this many alive (default 1024); false, and refused, below 1 or above 65536
  (when e is Emitter3d: wgr_emitter3d_set_max(e.cHandle, count.cint)
   else: wgr_emitter2d_set_max(e.cHandle, count.cint))

proc setLife*(e: Emitter; minSeconds, maxSeconds: float): bool {.discardable.} =
  (when e is Emitter3d: wgr_emitter3d_set_life(e.cHandle, minSeconds.cfloat, maxSeconds.cfloat)
   else: wgr_emitter2d_set_life(e.cHandle, minSeconds.cfloat, maxSeconds.cfloat))

proc prewarm*(e: Emitter; seconds: float): bool {.discardable.} =
  ## start over as if the steady rate had run for that long
  (when e is Emitter3d: wgr_emitter3d_prewarm(e.cHandle, seconds.cfloat)
   else: wgr_emitter2d_prewarm(e.cHandle, seconds.cfloat))

proc setSpawnBox*(e: Emitter3d; halfExtents: Vec3): bool {.discardable.} =
  ## born anywhere in a box around the position (half sizes; default a point)
  wgr_emitter3d_set_spawn_box(e.cHandle, halfExtents.x, halfExtents.y, halfExtents.z)

proc setSpawnSphere*(e: Emitter3d; radius: float): bool {.discardable.} =
  wgr_emitter3d_set_spawn_sphere(e.cHandle, radius.cfloat)

proc setVelocity*(e: Emitter3d; velocity: Vec3; spread = 0.0; speedVariance = 0.0): bool {.discardable.} =
  ## along `velocity` at its length's speed, turned up to `spread` radians off it and
  ## faster or slower by up to `speedVariance` (0..1) of it
  wgr_emitter3d_set_velocity(e.cHandle, velocity.x, velocity.y, velocity.z, spread, speedVariance)

proc setGravity*(e: Emitter3d; acceleration: Vec3): bool {.discardable.} =
  wgr_emitter3d_set_gravity(e.cHandle, acceleration.x, acceleration.y, acceleration.z)

proc setDrag*(e: Emitter; perSecond: float): bool {.discardable.} =
  ## slows particles in proportion to their speed (1 loses about 63% a second)
  (when e is Emitter3d: wgr_emitter3d_set_drag(e.cHandle, perSecond.cfloat)
   else: wgr_emitter2d_set_drag(e.cHandle, perSecond.cfloat))

proc setInheritVelocity*(e: Emitter; fraction: float): bool {.discardable.} =
  ## that fraction of the emitter's own movement, added at birth
  (when e is Emitter3d: wgr_emitter3d_set_inherit_velocity(e.cHandle, fraction.cfloat)
   else: wgr_emitter2d_set_inherit_velocity(e.cHandle, fraction.cfloat))

proc setSize*(e: Emitter; start, finish: float; variance = 0.0): bool {.discardable.} =
  ## from `start` at birth to `finish` at death, each particle's scaled by up to
  ## `variance` (0..1)
  (when e is Emitter3d: wgr_emitter3d_set_size(e.cHandle, start.cfloat, finish.cfloat, variance.cfloat)
   else: wgr_emitter2d_set_size(e.cHandle, start.cfloat, finish.cfloat, variance.cfloat))

proc setColor*(e: Emitter; start, finish: Color): bool {.discardable.} =
  ## from `start` at birth to `finish` at death, alpha included (a fade)
  (when e is Emitter3d: wgr_emitter3d_set_color(e.cHandle, start, finish)
   else: wgr_emitter2d_set_color(e.cHandle, start, finish))

proc addSizeKey*(e: Emitter; t, size: float): bool {.discardable.} =
  ## a curve point at `t` (0..1 of a particle's life), up to 8; clearSizeKeys first
  (when e is Emitter3d: wgr_emitter3d_add_size_key(e.cHandle, t.cfloat, size.cfloat)
   else: wgr_emitter2d_add_size_key(e.cHandle, t.cfloat, size.cfloat))

proc clearSizeKeys*(e: Emitter): bool {.discardable.} =
  (when e is Emitter3d: wgr_emitter3d_clear_size_keys(e.cHandle)
   else: wgr_emitter2d_clear_size_keys(e.cHandle))

proc addColorKey*(e: Emitter; t: float; color: Color): bool {.discardable.} =
  ## a curve point at `t` (0..1 of a particle's life), up to 8; clearColorKeys first
  (when e is Emitter3d: wgr_emitter3d_add_color_key(e.cHandle, t.cfloat, color)
   else: wgr_emitter2d_add_color_key(e.cHandle, t.cfloat, color))

proc clearColorKeys*(e: Emitter): bool {.discardable.} =
  (when e is Emitter3d: wgr_emitter3d_clear_color_keys(e.cHandle)
   else: wgr_emitter2d_clear_color_keys(e.cHandle))

proc addPaletteColor*(e: Emitter; color: Color): bool {.discardable.} =
  ## up to 8; each particle picks one at birth, and it tints the color over its life
  (when e is Emitter3d: wgr_emitter3d_add_palette_color(e.cHandle, color)
   else: wgr_emitter2d_add_palette_color(e.cHandle, color))

proc clearPalette*(e: Emitter): bool {.discardable.} =
  (when e is Emitter3d: wgr_emitter3d_clear_palette(e.cHandle)
   else: wgr_emitter2d_clear_palette(e.cHandle))

proc setSpin*(e: Emitter; min, max: float): bool {.discardable.} =
  ## radians per second, between min and max, from a random angle
  (when e is Emitter3d: wgr_emitter3d_set_spin(e.cHandle, min.cfloat, max.cfloat)
   else: wgr_emitter2d_set_spin(e.cHandle, min.cfloat, max.cfloat))

proc setStretch*(e: Emitter; seconds: float): bool {.discardable.} =
  ## streaks along the motion, as long as the distance moved in `seconds` (0: off)
  (when e is Emitter3d: wgr_emitter3d_set_stretch(e.cHandle, seconds.cfloat)
   else: wgr_emitter2d_set_stretch(e.cHandle, seconds.cfloat))

proc setAlphaMode*(e: Emitter; mode: AlphaMode; cutoff = 0.5): bool {.discardable.} =
  ## default AlphaMode.Add
  (when e is Emitter3d: wgr_emitter3d_set_alpha_mode(e.cHandle, ord(mode).cint, cutoff.cfloat)
   else: wgr_emitter2d_set_alpha_mode(e.cHandle, ord(mode).cint, cutoff.cfloat))

proc setSeed*(e: Emitter; seed: uint32): bool {.discardable.} =
  (when e is Emitter3d: wgr_emitter3d_set_seed(e.cHandle, seed.cuint)
   else: wgr_emitter2d_set_seed(e.cHandle, seed.cuint))

proc getCount*(e: Emitter): int =
  ## particles alive now
  (when e is Emitter3d: wgr_emitter3d_get_count(e.cHandle)
   else: wgr_emitter2d_get_count(e.cHandle)).int

proc clear*(e: Emitter) =
  ## all of them gone
  (when e is Emitter3d: wgr_emitter3d_clear(e.cHandle)
   else: wgr_emitter2d_clear(e.cHandle))

proc setVisible*(e: Emitter; visible: bool): bool {.discardable.} =
  (when e is Emitter3d: wgr_emitter3d_set_visible(e.cHandle, visible)
   else: wgr_emitter2d_set_visible(e.cHandle, visible))

proc draw*(e: Emitter) =
  ## immediate (a 3D one in 3D mode), for one not in a scene
  (when e is Emitter3d: wgr_emitter3d_draw(e.cHandle)
   else: wgr_emitter2d_draw(e.cHandle))

proc newEmitter2d*(texture: Texture): Emitter2d = Emitter2d(wgr_emitter2d_create(texture.cHandle))

proc destroy*(e: Emitter2d) = wgr_emitter2d_destroy(e.cHandle)

proc setPosition*(e: Emitter2d; value: Vec2): bool {.discardable.} =
  ## a move: the steady spawns spread along the way, and particles inherit its velocity
  wgr_emitter2d_set_position(e.cHandle, value.x, value.y)

proc setPosition*(e: Emitter2d; x, y: float): bool {.discardable.} =
  wgr_emitter2d_set_position(e.cHandle, x, y)

proc jump*(e: Emitter2d; value: Vec2): bool {.discardable.} =
  ## put it somewhere without a move: nothing spawns along the way
  wgr_emitter2d_jump(e.cHandle, value.x, value.y)

proc jump*(e: Emitter2d; x, y: float): bool {.discardable.} = wgr_emitter2d_jump(e.cHandle, x, y)

proc getPosition*(e: Emitter2d): Vec2 = wgr_emitter2d_get_position(e.cHandle).toNim

proc setSpawnBox*(e: Emitter2d; halfExtents: Vec2): bool {.discardable.} =
  ## born anywhere in a box around the position (half sizes; default a point)
  wgr_emitter2d_set_spawn_box(e.cHandle, halfExtents.x, halfExtents.y)

proc setSpawnCircle*(e: Emitter2d; radius: float): bool {.discardable.} =
  wgr_emitter2d_set_spawn_circle(e.cHandle, radius.cfloat)

proc setVelocity*(e: Emitter2d; velocity: Vec2; spread = 0.0; speedVariance = 0.0): bool {.discardable.} =
  ## along `velocity` at its length's speed (pixels per second), turned up to `spread`
  ## radians off it and faster or slower by up to `speedVariance` (0..1) of it
  wgr_emitter2d_set_velocity(e.cHandle, velocity.x, velocity.y, spread, speedVariance)

proc setGravity*(e: Emitter2d; acceleration: Vec2): bool {.discardable.} =
  wgr_emitter2d_set_gravity(e.cHandle, acceleration.x, acceleration.y)
