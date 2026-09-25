## wgr_version.h, wrapped.

import ./raw

proc versionMajor*(): int = wgr_version_major().int

proc versionMinor*(): int = wgr_version_minor().int

proc versionPatch*(): int = wgr_version_patch().int

proc versionLabel*(): string = $wgr_version_label() ## "dev", "rc1", or ""

proc versionNumber*(): int = wgr_version_number().int ## major * 10000 + minor * 100 + patch

proc versionString*(): string = $wgr_version_string()
