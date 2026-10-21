# DailyCorp Native 0.19.0 Alpha — Style B world packs 01–10

## Source audit
Source archive: `DailyCorp_World_StyleB_All_10_Packs.zip`.
- 10 directories, 1762 per-pack files plus archive README/index/summary (1765 entries).
- 173 MB compressed / ~180 MB uncompressed. The archive contains **only surface/world artwork**. Tin/titanium mining sprites are not part of this archive.
- Packs 01, 03 and 05: standalone concepts, **not seamless tiles**.
- Packs 02, 04 and 06: illustrated modular roads, water and sites, alpha cleanup; not guaranteed to snap seamlessly to grid.
- Packs 07–09: compatible isometric base tiles and transitions; Pack 09 also includes material textures for flat continent rasterization.
- Pack 10: cliffs, slopes and terraces (decorative overlays). Height and collision state remain in game logic, not from textures.

## Runtime integration (preserves saves and input geometry)
- Existing Style B continent atlas `styleb_materials.webp`: 8 source groups, cached **once** as one raster for a 96×72 continent grid; city coordinates are unchanged.
- Existing `styleb_isometric.webp`: ground diamonds from pack 09 plus selected 10/9 decorations; city background geometry still uses the 2:1 projection with the same lot/road hitboxes.
- Additional atlas `styleb_10_packs.webp` (1024×1024 WebP, 56 selected assets from **all 10 packs**, 170772 bytes):
  - Pack 01: 4 illustrated natural landmarks (sparse markers).
  - Pack 02: 3 water modules.
  - Pack 03: 3 art terrain transitions / construction accents.
  - Pack 04: 3 road/rail modules (road intersections shown rarely, not tiled as streets).
  - Pack 05: 4 conifers, rocks and shrubs.
  - Pack 06: 4 construction plot/ore outcrop icons, used for purchase-ready lots.
  - Pack 07: 8 basic isometric diamonds.
  - Pack 08: 3 relief overlays.
  - Pack 09: 20 material/terrain/transition selections.
  - Pack 10: 4 altitude overlays.
- All bitmap allocations occur on renderer startup, terrain atlas is loaded only once, and the flat continent texture is baked only once. Large diorama icons are used as sparse landmarks, never stamped over every road or cell.
- Terrain generation, city placement, lots, road collision, mines, trucks, contracts and save formats are NOT modified.

## Tin vs titanium sprite audit
- The submitted **world** ZIP contains no tin/titanium mining sprites; those are in an already existing separate `style_b_blocks.webp` mining atlas.
- The modern mine key table uses two distinct slots: `ore_tin` index 25, `ore_titanium` index 26. Resource IDs `ore_17_*` map to tin and `ore_6_*` map to titanium.
- The initial source visuals looked too close. Different color matrices are now applied in `MineBlockAtlas`: tin = warmer pale/metallic, titanium = cooler blue-steel; independent indices and save IDs unchanged.
- The old 132-cell fallback atlas does not have an explicit tin entry. Tin no longer falls back to the unrelated silver illustration; it now uses a visually distinct quartz-like reference while the dedicated modern atlas is preferred.
- Automated regression checks verify all 12 grades of each material have different sprite keys and verify both specific color filters exist. This does **not** mean the original source images were byte-for-byte identical; the modern presentation is differentiated deliberately.

## Limitations
Only 56 carefully chosen images are compiled from the 1762 files. Full procedural stitching of every neighbor bitmask and height transition is not yet included; those packs contain art prototypes unsuitable for simply pasting on every tile. Further work should implement a deterministic stitching ruleset and on-device preview of large biome borders without introducing map artifacts.
