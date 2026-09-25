## wgr_pick.h, wrapped.

import ./types, ./internal/convert, ./raw

proc toNim(r: CPickResult): PickResult =
  PickResult(hit: r.hit, handle: Handle(r.handle), distance: r.distance.float,
             pointLocal: r.point_local.toNim, pointWorld: r.point_world.toNim,
             normalLocal: r.normal_local.toNim, normalWorld: r.normal_world.toNim)

proc pick*(member: SceneMember; x, y: float; camera = Camera3d(0)): PickResult =
  ## one object alone, under a screen point; camera none: the active one
  wgr_pick_object(member.cHandle, camera.cHandle, x.cfloat, y.cfloat).toNim

proc getPickStats*(): PickStats =
  ## the tests picking has made since resetPickStats
  let s = wgr_pick_get_stats()
  PickStats(broadphaseTests: s.broadphase_tests.int, broadphaseRejects: s.broadphase_rejects.int,
            narrowphaseTests: s.narrowphase_tests.int, narrowphaseHits: s.narrowphase_hits.int)

proc resetPickStats*() = wgr_pick_reset_stats()
