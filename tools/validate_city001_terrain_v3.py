"""Offline terrain acceptance tests; reads real GLB and real reference-derived layout."""
from pathlib import Path
from collections import Counter
import struct, json, math
import networkx as nx
import numpy as np
from shapely.geometry import LineString,Point
from shapely.ops import unary_union
import trimesh
import build_terrain_v3 as v3

p=Path(__file__).resolve().parent
manifest=json.loads((p/'city001_terrain_v3.json').read_text(encoding='utf8'))
assert manifest['schema']=='dailycorp.city001.terrain.v3'
assert manifest['source']['pixelSize']==[1536,1024]
assert len(manifest['sites'])==13
expected=dict(MINE=3,FACTORY=2,WAREHOUSE=4,RESEARCH=1,MUNICIPAL=1,ENERGY=1,MARKET=1)
assert Counter(x['kind'] for x in manifest['sites'])==expected
for site in manifest['sites']:
 u,v=site['referencePixel'];x,y,z=site['world']
 assert abs(x-(u-768)*.1)<.0001 and abs(z-(v-512)*.1)<.0001
 assert abs(y-v3.surface_at(x,z)-.2)<.002
 assert site['gameplayBinding']==dict(cityId=1,kind=site['kind'],ordinal=site['ordinal'])

for filename in ['city001_terrain_v3.glb','city001_terrain_only_v3.glb']:
 data=(p/filename).read_bytes()
 assert data[:4]==b'glTF' and struct.unpack_from('<I',data,4)[0]==2
 assert struct.unpack_from('<I',data,8)[0]==len(data)
 scene=trimesh.load(p/filename,force='scene')
 assert 'TERRAIN_GEO' in scene.geometry and 'CLIFFS_COAST_REAL' in scene.geometry
 assert 'ISLETS_ROCK' in scene.geometry
 if 'terrain_only' not in filename:
  assert len(scene.geometry)>=100
  for k,n in expected.items():
   for i in range(n):assert f'LOT_{k}_{i}' in scene.geometry
 else:
  assert len(scene.geometry)<25
  assert not any(name.startswith('LOT_') for name in scene.geometry)
 assert all(math.isfinite(z) for mesh in scene.geometry.values() for z in mesh.bounds.ravel())

# Topographic relief genuinely excavates each mine within its surrounding rim.
for q in v3.QUARRIES:
 u,v=q['center'];rx,ry=q['radius']
 center=v3.surface_at(v3.world_x(u),v3.world_z(v))
 rim=[v3.surface_at(v3.world_x(u+rx*.98*math.cos(t)),v3.world_z(v+ry*.98*math.sin(t)))
      for t in np.linspace(0,2*math.pi,24,endpoint=False)]
 assert np.median(rim)-center>2.0, (q['id'],center,np.median(rim))
 assert min(rim)>center+.2, (q['id'],center,min(rim))

# Main waterfall river descends overall from northern mountains to sea.
east=v3.RIVERS[0]['points']
head=v3.surface_at(v3.world_x(east[0][0]),v3.world_z(east[0][1]))
mouth=v3.surface_at(v3.world_x(east[-1][0]),v3.world_z(east[-1][1]))
assert head>mouth+4, (head,mouth)

roads=[LineString(x['pts']) for x in manifest['roads']]
G=nx.Graph()
for fragment in unary_union(roads).geoms:
 coords=list(fragment.coords)
 for a,b in zip(coords,coords[1:]):G.add_edge(tuple(round(c,5) for c in a),tuple(round(c,5) for c in b))
assert nx.number_connected_components(G)==1
for site in manifest['sites']:
 assert min(Point(site['referencePixel']).distance(rd) for rd in roads)<4.1
rivers=[LineString(x['points']) for x in manifest['rivers']]
for road in roads:
 for river in rivers:
  crossing=road.intersection(river)
  if crossing.is_empty:continue
  assert hasattr(crossing,'x')
  assert any(Point(b['p']).distance(crossing)<7 for b in manifest['bridges'])

assert (p/'terrain_height_16bit_v3.png').is_file()
assert (p/'terrain_landmask_v3.png').is_file()
print('PASS — Terrain v3: exact 13 site anchors, GLB geometry, 3 excavated quarries, river fall, connected streets, bridges, 16-bit heightmap')
print('min/max relief:',round(float(v3.heights.min()),2),round(float(v3.heights.max()),2),'geometry triangles:',manifest['geometryStats']['triangles'])