## What the modules share but a program doesn't see: the C side of a handle, and C
## vectors as Nim ones. wgr.nim doesn't export this module.

import ../types, ../raw

# The C side's handle, for raw's calls: seen by the wgr modules, not by a program, so to
# one a handle stays a handle.
template cHandle*(h: Handle): WgrHandle = WgrHandle(uint32(h))

template cHandle*(h: AnyHandle): WgrHandle = WgrHandle(uint32(Handle(h)))

proc toNim*(v: CVec2): Vec2 = (v.x.float, v.y.float)

proc toNim*(v: CVec3): Vec3 = (v.x.float, v.y.float, v.z.float)
