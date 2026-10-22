#!/usr/bin/env python3
"""DailyCorp City 001 reference-aligned, editable GLB blockout v0.2.

Coordinates are manually registered to approved 1536x1024 mirrored city art.
All 3D meshes are actual geometry with vertex colors, not a panorama bitmap.
The reference is a 2D illustration: absolute depths/heights are design choices.
"""
import json, math, random, hashlib, os
from pathlib import Path
import numpy as np
import trimesh
from PIL import Image,ImageDraw,ImageFont
from scipy.ndimage import gaussian_filter, distance_transform_edt
from matplotlib.path import Path as MplPath

HERE=Path(__file__).resolve().parent
SOURCE=Path(os.environ.get('DAILYCORP_CITY001_REFERENCE',str(HERE/'approved_city001_reference.png')))
W,H=1536,1024
WORLD_PER_PIXEL=0.10
rgen=np.random.default_rng(1012026)

SITES=[
 ('MINE',0,'Шахта 1',1190,222,[1160,145],'FOR_SALE',14.0),
 ('MINE',1,'Шахта 2',553,151,[520,101],'FOR_SALE',15.0),
 ('MINE',2,'Шахта 3',1342,641,[1350,588],'FOR_SALE',11.0),
 ('FACTORY',0,'Завод 1',549,407,[550,348],'FOR_SALE',3.4),
 ('FACTORY',1,'Завод 2',337,537,[348,465],'FOR_SALE',3.5),
 ('WAREHOUSE',0,'Склад 1',1006,700,[981,661],'FOR_SALE',3.4),
 ('WAREHOUSE',1,'Склад 2',775,572,[744,515],'FOR_SALE',3.4),
 ('WAREHOUSE',2,'Склад 3',232,600,[226,547],'FOR_SALE',3.4),
 ('WAREHOUSE',3,'Склад 4',396,724,[393,677],'FOR_SALE',3.4),
 ('RESEARCH',0,'Научный центр',324,254,[297,198],'CIVIC',5.1),
 ('MUNICIPAL',0,'Мэрия',790,262,[744,197],'CIVIC',4.8),
 ('ENERGY',0,'Электростанция',1070,398,[1075,344],'CIVIC',6.0),
 ('MARKET',0,'Рынок',831,413,[832,374],'CIVIC',3.3),
]
assert len(SITES)==13
assert sorted([(k,sum(x[0]==k for x in SITES)) for k in set(s[0] for s in SITES)])==sorted([('MINE',3),('FACTORY',2),('WAREHOUSE',4),('RESEARCH',1),('MUNICIPAL',1),('ENERGY',1),('MARKET',1)])

LAND=[(274,0),(930,0),(1428,0),(1518,44),(1460,126),(1444,223),
 (1510,330),(1536,472),(1522,601),(1495,710),(1411,744),(1333,775),
 (1222,765),(1136,783),(1050,775),(970,796),(861,775),(769,805),
 (673,811),(574,824),(504,800),(413,785),(330,804),(260,783),
 (195,769),(153,797),(88,769),(0,742),(0,463),(63,448),(117,425),
 (126,368),(84,310),(29,270),(0,232),(84,203),(153,137),(188,69)]
# Additional bays/open water carved into peninsula edge and estuary
SEA_COVES=[[(0,0),(274,0),(210,81),(159,147),(98,199),(0,224)],
 [(0,463),(55,457),(98,480),(120,551),(93,628),(0,662)],
 [(1495,96),(1536,65),(1536,458),(1521,415),(1487,354),(1458,276)],
 [(0,738),(180,763),(278,788),(408,796),(519,831),(736,825),(879,801),(999,819),(1197,796),(1399,770),(1536,741),(1536,1024),(0,1024)]]
# River canyon from mountain plateau through eastern center to marine inlet
RIVERS=[
 {'id':'river_east','points':[(992,26),(995,70),(1016,108),(1030,143),(1039,185),(1025,222),(1017,265),(1000,297),(1004,338),(1014,376),(1065,416),(1051,459),(1040,501),(1077,554),(1129,598),(1158,655),(1192,721),(1188,789)],'width_px':18},
 {'id':'river_west','points':[(115,185),(139,240),(129,282),(157,332),(141,381),(172,428),(189,471)],'width_px':12}
]
BRIDGES=[
 {'id':'west_river_bridge','p':(155,338),'span_px':28,'class':'bridge'},
 {'id':'north_culvert','p':(1023,125),'span_px':22,'class':'culvert'},
 {'id':'civic_bridge','p':(1034,160),'span_px':24,'class':'bridge'},
 {'id':'central_canyon_bridge','p':(1007,348),'span_px':33,'class':'bridge'},
 {'id':'warehouse_bridge','p':(1049,465),'span_px':28,'class':'bridge'},
 {'id':'eastern_quarry_bridge','p':(1177,693),'span_px':28,'class':'bridge'}]
WATERFALLS=[{'id':'east_upper','p':(1045,424),'drop':6}, {'id':'east_lower','p':(1184,751),'drop':8}, {'id':'west_fall','p':(148,385),'drop':7}]
# Main road axes manually traced between saved sites, intersection-level schematic
ROADS=[
 {'id':'B0_north_cross','pts':[(160,198),(302,265),(471,345),(611,420),(751,485),(899,558),(1031,634),(1188,722)],'type':'arterial'},
 {'id':'B1_central_cross','pts':[(100,310),(240,380),(390,456),(545,534),(695,609),(866,682),(1022,749)],'type':'arterial'},
 {'id':'B2_south_cross','pts':[(145,522),(274,584),(410,646),(555,722),(704,798)],'type':'arterial'},
 {'id':'A0_north_south','pts':[(243,394),(393,325),(548,245),(695,166),(827,93)],'type':'arterial'},
 {'id':'A1_civic_axis','pts':[(205,570),(340,503),(492,436),(629,360),(781,278),(910,215),(1045,155)],'type':'arterial'},
 {'id':'A2_center_axis','pts':[(321,693),(452,621),(609,541),(765,463),(916,390),(1090,310),(1224,243)],'type':'arterial'},
 {'id':'A3_warehouse_axis','pts':[(415,790),(558,719),(702,645),(845,565),(1000,492),(1141,415),(1281,347)],'type':'arterial'},
 {'id':'A4_power_access','pts':[(1086,376),(1167,312),(1258,253),(1341,227),(1440,232)],'type':'access'},
 {'id':'A5_east_mine_access','pts':[(1050,730),(1170,696),(1250,658),(1340,641)],'type':'access'},
 {'id':'A6_north_mine_access','pts':[(845,160),(949,119),(1065,129),(1170,204)],'type':'access'},
 {'id':'A7_mine2_access','pts':[(473,344),(467,248),(520,176),(553,151)],'type':'access'},
 {'id':'A8_harbour_entrance','pts':[(395,722),(422,789),(482,845),(560,885)],'type':'access'},
 {'id':'A9_warehouses','pts':[(232,600),(308,646),(396,724),(489,772)],'type':'access'},
 {'id':'A10_lot1','pts':[(549,407),(599,435),(649,451)],'type':'access'},
 {'id':'A11_lot2','pts':[(337,537),(392,531),(427,546)],'type':'access'},
 {'id':'A12_municipal','pts':[(790,262),(795,312),(770,356)],'type':'access'},
 {'id':'A13_market','pts':[(831,413),(807,446),(765,463)],'type':'access'},
 {'id':'A14_research','pts':[(324,254),(329,319),(393,325)],'type':'access'},
 {'id':'A15_warehouse1','pts':[(1006,700),(1022,749)],'type':'access'},
 {'id':'A16_warehouse2','pts':[(775,572),(845,565)],'type':'access'},
 {'id':'A17_electric','pts':[(1070,398),(1086,376)],'type':'access'}]
# Short linking streets keep the reference road network connected instead of
# leaving floating access lines as in the prior prototype.
ROADS.extend([
 {'id':'C0_mine1_main_link','pts':[(1224,243),(1239,266)],'type':'access'},
 {'id':'C1_north_road_link','pts':[(1045,155),(1047,127)],'type':'access'},
 {'id':'C2_factory1_link','pts':[(549,407),(544,402)],'type':'access'},
 {'id':'C3_factory2_link','pts':[(337,537),(320,506)],'type':'access'},
 {'id':'C4_mine1_gate','pts':[(1170,204),(1190,222)],'type':'access'}
])
# Reducing visual mismatches: residential pockets, central park, ports, forest belts
RESIDENTIAL=[
 {'name':'west','polygon':[(166,401),(283,332),(440,399),(357,496),(263,537)]},
 {'name':'central','polygon':[(443,453),(614,450),(742,520),(655,637),(480,587)]},
 {'name':'upper_center','polygon':[(561,253),(704,202),(886,287),(808,378),(651,388)]},
 {'name':'south_center','polygon':[(461,627),(659,638),(795,738),(624,773)]},
 {'name':'east_center','polygon':[(891,417),(1026,436),(1115,518),(972,605)]}]
FORESTS=[
 {'name':'north_forest','polygon':[(0,0),(1536,0),(1501,116),(1280,87),(1090,97),(925,76),(765,89),(599,89),(388,70),(193,106),(0,139)]},
 {'name':'west_forest','polygon':[(0,325),(162,377),(253,487),(155,573),(0,548)]},
 {'name':'east_forest','polygon':[(1211,330),(1490,265),(1536,387),(1420,491),(1220,459)]},
 {'name':'south_ridge','polygon':[(662,728),(822,713),(986,776),(1123,752),(1360,784),(1258,855),(724,869)]}]
QUARRIES=[{'id':'mine1_quarry','center':(1190,222),'radius':[95,70]},
          {'id':'mine2_quarry','center':(553,151),'radius':[94,70]},
          {'id':'mine3_quarry','center':(1342,641),'radius':[112,76]}]
PORT=[{'id':'pier1','points':[(359,786),(388,846),(412,887)]},
      {'id':'pier2','points':[(477,792),(499,851),(522,891)]},
      {'id':'pier3','points':[(577,826),(586,881),(591,907)]}]

# World coordinates use glTF-standard right-handed Y-up; screen drawing planes x,z.
def world_x(u):return (u-W/2)*WORLD_PER_PIXEL
def world_z(v):return (v-H/2)*WORLD_PER_PIXEL

def write_manifest():
 sites=[]
 for kind,ordinal,name,u,v,label,state,goal in SITES:
  sites.append({'id':f'{kind.lower()}_{ordinal+1}', 'kind':kind,'ordinal':ordinal,
   'name':name,'referencePixel':[u,v],'referenceLabelPixel':label,
   'world':[round(world_x(u),2),None,round(world_z(v),2)],
   'designPlateauY':goal,'state':(state if kind=='MINE' else 'RUNTIME' if kind in ('FACTORY','WAREHOUSE') else state),'gameplayBinding':{'cityId':1,'kind':kind,'ordinal':ordinal},
   'buildingFootprintWorld':[6 if kind!='MINE' else 10,5 if kind!='MINE' else 8]})
 m={'schema':'dailycorp.city001.blockout.v2','description':'Geometric tracing of manually approved mirrored reference; 2D location trusted, height estimates iterative',
 'source':{'referenceFile':'a_highly_detailed_isometric_game_map_illustration.png','pixelSize':[W,H],
           'sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest() if SOURCE.is_file() else 'b6c8ac0e1cf2c37aa115dea2671603bd5c2503894cb66c236c818ee70650a680'},
 'coordinateSystem':{'glTF':'right handed Y up','pixelToWorld':{'x':'(u-768)*0.1','z':'(v-512)*0.1','y':'terrainHeight(u,v)'},
 'worldFootprint':[153.6,102.4],'projection':'ref layout, not inverse photogrammetry'},
 'camera':{'type':'orthographic','azimuthDegrees':-30,'elevationDegrees':51,'target':[0,5,0],'heightWorld':148,
           'compareView':'use the original reference as parallel overlay, no textured billboard'},
 'layers':['SEA','TERRAIN','CLIFFS','QUARRIES','RIVERS','WATERFALLS','BRIDGES','ROADS','FOREST','HOUSING','HARBOR','INTERACTABLE_SITES'],
 'landOutlineReferencePixels':LAND,'seaCoves':SEA_COVES,'rivers':RIVERS,'bridges':BRIDGES,'waterfalls':WATERFALLS,
 'quarries':QUARRIES,'roads':ROADS,'residentialZones':RESIDENTIAL,'forests':FORESTS,'piers':PORT,'sites':sites,
 'acceptance':{'expectedSites':13,'noGameLogicMigration':True,'keepOther47CitiesUntouched':True,
 'roadGraphMustEventuallyBeValidated':True,'heightIsEstimatedNotSurveyed':True,
 'metric':'Compare projected 3D anchor screen coordinates against reference; area ratios / silhouette after camera lock'},
 'version':'2.0-blockout-draft'}
 return m

colors={'ocean':'#0a638e','grass':'#568c55','rock':'#8f9091','road':'#404c50','quarry':'#bb8a54','river':'#2ca6d0','housing':'#d7cba9',
'MINE':'#f08c29','FACTORY':'#db414b','WAREHOUSE':'#319cf0','RESEARCH':'#b76add','MUNICIPAL':'#4db6dc','ENERGY':'#ffd04f','MARKET':'#2bb88a'}

def annotate(image,manifest):
 im=image.convert('RGBA'); mask=Image.new('RGBA',im.size,(0,0,0,0)); d=ImageDraw.Draw(mask,'RGBA')
 # zone washes are transparent to maintain legibility
 for group,pts,fill,outline in [
  ('port',[(265,710),(685,710),(700,900),(320,923)],(0,146,204,35),(20,230,242,220)),
  ('civic',[(655,192),(940,190),(970,490),(730,480)],(50,193,180,25),(36,237,187,190)),
  ('industry',[(245,355),(650,335),(670,650),(200,675)],(223,99,48,22),(255,149,62,175)),
  ('north_mountains',[(280,0),(1450,0),(1515,285),(310,245)],(155,155,178,16),(207,213,237,170))]:
   d.line(pts+[pts[0]], fill=outline,width=5)
 # Line guides for roads and water
 for r in ROADS:
  coords=r['pts']; d.line(coords,fill=(255,255,255,135) if r['type']=='arterial' else (255,204,83,175),width=4)
 for r in RIVERS:d.line(r['points'],fill=(0,218,255,230),width=7)
 for q in QUARRIES:
  u,v=q['center'];rx,ry=q['radius'];d.ellipse((u-rx,v-ry,u+rx,v+ry),outline=(255,160,36,230),width=5)
 # unique numbered sites prominent to distinguish from baked labels
 try:
  font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',21)
  fontsm=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',18)
 except:font=fontsm=ImageFont.load_default()
 for i,s in enumerate(manifest['sites'],1):
  u,v=s['referencePixel']; col=colors[s['kind']];r=int(col[1:3],16);g=int(col[3:5],16);b=int(col[5:7],16)
  d.ellipse((u-18,v-18,u+18,v+18),fill=(18,37,50,235),outline=(r,g,b,255),width=5)
  label=str(i);bb=d.textbbox((0,0),label,font=font)
  d.text((u-(bb[2]-bb[0])/2,v-(bb[3]-bb[1])/2-4),label,font=font,fill=(255,255,255,255))
 im=Image.alpha_composite(im,mask).convert('RGB')
 # add marginal strip with legend
 legend=Image.new('RGB',(W,180),(13,30,45));ld=ImageDraw.Draw(legend)
 ld.text((24,13),'DAILYCORP CITY 001 · 3D BLOCKOUT V2 · REFERENCE ALIGNMENT / 13 LOTS',font=font,fill='white')
 for idx,s in enumerate(manifest['sites']):
  col=colors[s['kind']]; x=20+(idx%7)*213;y=55+(idx//7)*57
  ld.ellipse((x,y,x+27,y+27),fill=col)
  ld.text((x+37,y+4),f'{idx+1:02d} · {s["id"]}',font=fontsm,fill='#f4f5f7')
 out=Image.new('RGB',(W,H+180));out.paste(im,(0,0));out.paste(legend,(0,H));out.save(HERE/'city001_reference_layout_v2.png',optimize=True)

# geometry tools use trimesh meshes accumulated by semantic layer
meshes={}

def add(name,m,color):
 if m is None:return
 m.visual.vertex_colors=trimesh.visual.color.hex_to_rgba(color)
 if name in meshes:meshes[name].append(m)
 else:meshes[name]=[m]

def box(name,center,extents,col):
 m=trimesh.creation.box(extents=extents);m.apply_translation(center);add(name,m,col)

def cone(name,cx,y,cz,base,height,col,sections=5):
 m=trimesh.creation.cone(radius=base,height=height,sections=sections);m.apply_transform(trimesh.transformations.rotation_matrix(-math.pi/2,[1,0,0])) # cone Z-axis ->? rotated -90 around X: Z maps +Y
 m.apply_translation([cx,y,cz]);add(name,m,col)

def cylinder(name,cx,y,cz,radius,height,col,sections=8):
 m=trimesh.creation.cylinder(radius=radius,height=height,sections=sections)
 m.apply_transform(trimesh.transformations.rotation_matrix(-math.pi/2,[1,0,0]));m.apply_translation([cx,y,cz]);add(name,m,col)

def segment(name,a,b,width,col,yy=0.12):
 # long prism segment aligned to horizontal xz world; y follows sampled terrain below
 x1,z1=map(float,a);x2,z2=map(float,b)
 dx=x2-x1;dz=z2-z1;dist=math.hypot(dx,dz)
 if dist<1e-5:return
 h1=surface_at(x1,z1)+yy;h2=surface_at(x2,z2)+yy
 # create prism averaged incline, sufficient to show the mapping
 avg=(h1+h2)/2
 m=trimesh.creation.box(extents=[dist,.095,width])
 m.apply_transform(trimesh.transformations.rotation_matrix(math.atan2(-dz,dx),[0,1,0]))
 m.apply_translation([(x1+x2)/2,avg,(z1+z2)/2]);add(name,m,col)

def polygon_mask(pts,xx,yy):
 path=MplPath(np.array(pts,dtype=float),closed=True)
 points=np.column_stack([xx.ravel(),yy.ravel()]);return path.contains_points(points).reshape(xx.shape)

# moderate terrain resolution to stay GLES2-compatible and avoid >65k mesh vertices
GX=160; GZ=112
us=np.linspace(0,W,GX);vs=np.linspace(0,H,GZ);U,V=np.meshgrid(us,vs)
landmask=polygon_mask(LAND,U,V)
for cove in SEA_COVES:landmask &= ~polygon_mask(cove,U,V)
# smooth land-ocean transition; cliffs remain visible via north/east hills
inside=distance_transform_edt(landmask);outside=distance_transform_edt(~landmask)
coast=np.clip((inside-outside+1)/5,0,1)
base=(2.8 + 0.45*np.cos(U/155)+0.5*np.sin(V/119))
base+=8*np.exp(-((V-3)/110)**2) * np.clip((U-125)/270,0,1)
for mountain_x,peak_height,peak_width in [(300,12,72),(680,15,100),(925,22,80),(1280,17,105),(1450,15,75)]:
 base += peak_height * np.exp(-((U-mountain_x)/peak_width)**2 - ((V-45)/100)**2)
base+=9*np.exp(-((U-1440)/176)**2 - ((V-252)/240)**2)
base+=7*np.exp(-((U-1350)/150)**2 - ((V-582)/170)**2)
base+=7*np.exp(-((U-550)/125)**2 - ((V-125)/117)**2)
base+=7*np.exp(-((U-1170)/160)**2 - ((V-178)/154)**2)
base+=2.5*np.exp(-((U-85)/110)**2 - ((V-470)/250)**2)
noise=gaussian_filter(rgen.normal(size=U.shape),1.7)*1.85
base += noise* np.minimum(1, np.maximum(0, ((base-3)/10)))
# flatten urban center; keep upper hills
urban_flat= np.exp(-((U-680)/540)**6-((V-494)/270)**6)
base=base*(1-urban_flat*.45)+3.5*(urban_flat*.45)
# Flatten site pads to a stable known target, physical heights recompute later
for kind,ord_,_,u,v,_,_,pady in SITES:
 rr=((U-u)/42)**2+((V-v)/36)**2
 factor=np.exp(-rr**2)*0.97
 base=base*(1-factor)+pady*factor
# rivers carve actual river beds; image river corridor approximate
for river in RIVERS:
 for a,b in zip(river['points'],river['points'][1:]):
  p=np.array(b)-np.array(a);q=p/np.dot(p,p)
  t=np.clip(((U-a[0])*p[0]+(V-a[1])*p[1])*q.sum() if False else (((U-a[0])*p[0]+(V-a[1])*p[1])/np.dot(p,p)),0,1)
  d2=(U-a[0]-t*p[0])**2+(V-a[1]-t*p[1])**2
  carve=np.exp(-d2/(river['width_px']*1.35)**2)
  base-=3*carve
heights=-2.8+(np.clip(base,0,36)+2.8)*coast

# nearest interpolated height, x,z units->reference pixel
def surface_at(x,z):
 u=(x/WORLD_PER_PIXEL)+W/2;v=(z/WORLD_PER_PIXEL)+H/2
 a=np.clip(u/W*(GX-1),0,GX-1-.001);b=np.clip(v/H*(GZ-1),0,GZ-1-.001)
 i=int(a);j=int(b);tx=a-i;tz=b-j
 return float((1-tx)*(1-tz)*heights[j,i] + tx*(1-tz)*heights[j,i+1]+(1-tx)*tz*heights[j+1,i]+tx*tz*heights[j+1,i+1])

def terrain_mesh():
 verts=[];faces=[]
 for j in range(GZ):
  for i in range(GX):verts.append([world_x(us[i]),float(heights[j,i]),world_z(vs[j])])
 for j in range(GZ-1):
  for i in range(GX-1):
   a=j*GX+i;faces.append([a,a+GX,a+1]);faces.append([a+1,a+GX,a+GX+1])
 mesh=trimesh.Trimesh(vertices=verts,faces=faces,process=False)
 colorsarr=[]
 for j in range(GZ):
  for i in range(GX):
   h=heights[j,i];rx=U[j,i];ry=V[j,i]
   if h<0:cl=(13,119,160,255)
   elif h>13:cl=(128,132,130,255)
   elif h>8:cl=(116,137,112,255)
   elif rx>1270 and ry>485:cl=(153,137,111,255)
   else:cl=(92,151,93,255)
   colorsarr.append(cl)
 mesh.visual.vertex_colors=colorsarr
 meshes['TERRAIN_GEO']=[mesh]

def polyline(name,points,width,color):
 for a,b in zip(points,points[1:]):
  segment(name,(world_x(a[0]),world_z(a[1])),(world_x(b[0]),world_z(b[1])),width,color)

def build_quarries():
 for q in QUARRIES:
  u,v=q['center'];rx,ry=q['radius'];gid=q['id']
  # Stone-capped ring, hewn terraces, orange spoil heaps
  for ring in [0.92,0.74,0.57]:
   seg=[]
   for t in np.linspace(0,2*math.pi,19):seg.append((world_x(u+rx*ring*math.cos(t)), world_z(v+ry*ring*math.sin(t))))
   polyline('QUARRIES_'+gid,[(x/WORLD_PER_PIXEL+W/2,z/WORLD_PER_PIXEL+H/2) for x,z in seg],.36,'#c6a06f')
  for i in range(8):
   a=2*math.pi*(i/8);px=world_x(u+rx*.47*math.cos(a));pz=world_z(v+ry*.4*math.sin(a));py=surface_at(px,pz)
   box('QUARRIES_'+gid,(px,py+.4,pz),(1.1,.8,1), '#c4a883')

def building(name,px,py,pz,kind,variant=0):
 col={'MINE':'#bb8a56','FACTORY':'#bd5b49','WAREHOUSE':'#6b8ba7','MUNICIPAL':'#cfcec3','RESEARCH':'#cfd9da','ENERGY':'#c4c6c3','MARKET':'#ce9b61'}[kind]
 if kind=='MINE':
  box(name,(px,py+.25,pz),(8,.5,7),'#af8455')
  box(name,(px-.3,py+2.2,pz),(2,3.7,2),col)
  box(name,(px-.3,py+4.3,pz),(3,.35,3),'#d2b384')
  for offs in [-2,2.6]:box(name,(px+offs,py+1,pz+2),(1.4,1.8,1.5),'#8d8d88')
 elif kind=='FACTORY':
  box(name,(px,py+1.4,pz),(6.3,2.8,5.2),'#adb7b7');box(name,(px,py+3,pz),(6.8,.45,5.6),'#c15e4e')
  box(name,(px-2,py+1.3,pz-3.1),(2,2.4,1.8),'#778b9c')
  for off in [-1.4,1.5]:cylinder(name,px+off,py+5.1,pz-1.2,.38,5,'#a85244',10)
 elif kind=='WAREHOUSE':
  box(name,(px,py+1.4,pz),(6.2,2.8,4.9),'#d7ddd8')
  box(name,(px,py+3.0,pz),(6.6,.45,5.25),'#5d80a6')
  for off in [-1.3,1.2]:box(name,(px+off,py+1.0,pz+2.48),(1.8,1.8,.11),'#71828a')
 elif kind=='RESEARCH':
  box(name,(px,py+1.5,pz),(6,3.0,5.2),'#d1dde2')
  for off in [-2,2]:cylinder(name,px+off,py+4.25,pz,.98,5.4,'#73aed0',12)
 elif kind=='MUNICIPAL':
  box(name,(px,py+2.2,pz),(6.4,4.4,5.6),'#efe6d7')
  box(name,(px,py+4.6,pz),(7,.35,6),'#4675a9');cylinder(name,px,py+5.15,pz,2,1.1,'#4c86b5',16)
 elif kind=='ENERGY':
  box(name,(px,py+1.5,pz),(6,3.0,6),'#c3c8c4')
  for off in [-1.7,1.7]:cylinder(name,px+off,py+5.7,pz,.48,7.8,'#dbdfde',12)
 elif kind=='MARKET':
  for i in [-1.6,0,1.6]:box(name,(px+i,py+.8,pz),(1.2,1.6,2),'#f4e3c3');box(name,(px,py+2.05,pz),(6,.5,5),'#c5754f')


def build():
 terrain_mesh()
 # Sea independent water plane, in 3D - not textured plane
 box('SEA', (0,-2.56,0), (W*WORLD_PER_PIXEL,.08,H*WORLD_PER_PIXEL),'#116e9b')
 for river in RIVERS:polyline('RIVERS_'+river['id'],river['points'],river['width_px']*WORLD_PER_PIXEL,'#218baf')
 for route in ROADS:
  polyline('ROADS_SHOULDER_'+route['id'],route['pts'], 2.15 if route['type']=='arterial' else 1.75,'#cebda2')
  polyline('ROADS_ASPHALT_'+route['id'],route['pts'],1.48 if route['type']=='arterial' else 1.16,'#424b4e')
 # Bridges distinct from plain roads
 for bridge in BRIDGES:
  u,v=bridge['p'];rx=world_x(u);rz=world_z(v);hy=surface_at(rx,rz)+1.25
  box('BRIDGES_'+bridge['id'],(rx,hy,rz),(8,.35,2.0),'#c2bba7')
 # waterfall ribbons, bridge railings / canyon
 for fall in WATERFALLS:
  u,v=fall['p'];x=world_x(u);z=world_z(v);hy=surface_at(x,z)
  box('WATERFALLS_'+fall['id'],(x,hy-fall['drop']/2,z),(1.9,fall['drop'],.35),'#4dcce2')
 build_quarries()
 # Sites, pads and distinct 3D structures: actual 13 scene nodes
 occupied=[]
 for k,ord_,name,u,v,lbl,state,goal in SITES:
  x,z=world_x(u),world_z(v);y=surface_at(x,z)+.2
  root=f'LOT_{k}_{ord_}'
  box(root,(x,y-.1,z),(11 if k=='MINE' else 8,.20,9 if k=='MINE' else 7.5),'#c9c7a4')
  building(root,x,y,z,k)
  occupied.append((u,v))
 # scatter housing within declared polygons avoiding sites and roads
 mask_housing=np.zeros_like(heights,dtype=bool)
 for neighborhood in RESIDENTIAL:mask_housing|=polygon_mask(neighborhood['polygon'],U,V)
 road_segments=[]
 for r in ROADS:
  for a,b in zip(r['pts'],r['pts'][1:]):road_segments.append((a,b))
 def nearto_road(u,v):
  for a,b in road_segments:
   dx=b[0]-a[0];dy=b[1]-a[1];t=max(0,min(1,((u-a[0])*dx+(v-a[1])*dy)/(dx*dx+dy*dy+1e-5)))
   if (u-a[0]-dx*t)**2+(v-a[1]-dy*t)**2 < 20**2:return True
  return False
 home_count=0
 for zone in RESIDENTIAL:
  from shapely.geometry import Point as SP,Polygon
  pg=Polygon(zone['polygon']);minx,miny,maxx,maxy=pg.bounds
  for _ in range(120):
   u=float(rgen.uniform(minx,maxx));v=float(rgen.uniform(miny,maxy))
   if not pg.contains(SP(u,v)) or nearto_road(u,v) or any((u-o[0])**2+(v-o[1])**2<55**2 for o in occupied):continue
   x,z=world_x(u),world_z(v);y=surface_at(x,z)
   if y<.3:continue
   rw=float(rgen.uniform(1.0,1.65));h=float(rgen.uniform(1.4,3.2))
   box('HOUSING_'+zone['name'],(x,y+h/2,z),(rw,h,rw),'#dfdbc8')
   box('HOUSING_ROOFS_'+zone['name'],(x,y+h+.15,z),(rw*1.18,.3,rw*1.18),['#a75951','#5679a1','#9e6757'][home_count%3]);home_count+=1
 # forest regions and sloped cliff edges with actual 3D trees
 from shapely.geometry import Polygon,Point as SP
 tree_count=0
 for forest in FORESTS:
  poly=Polygon(forest['polygon']);minx,miny,maxx,maxy=poly.bounds
  for j in range(260):
   u=float(rgen.uniform(minx,maxx));v=float(rgen.uniform(miny,maxy))
   if not poly.contains(SP(u,v)) or nearto_road(u,v) or any((u-o[0])**2+(v-o[1])**2<38**2 for o in occupied):continue
   x,z=world_x(u),world_z(v);y=surface_at(x,z)
   if y<=0:continue
   h=float(rgen.uniform(.9,2.2))
   cone('FOREST_'+forest['name'],x,y+h*.50,z,h*.24,h,'#376e51',5);tree_count+=1
 # piers port
 for pier in PORT:
  polyline('HARBOR_'+pier['id'],pier['points'],1.7,'#d7cbb0')
  for u,v in pier['points']:
   x,z=world_x(u),world_z(v);box('HARBOR_CRANES',(x,max(0,surface_at(x,z))+1.2,z),(.3,2.4,.3),'#e6a340')
 return {'houses':home_count,'trees':tree_count}

def export_glb():
 scene=trimesh.Scene()
 categories={}
 for name,items in meshes.items():
  combined=trimesh.util.concatenate(items)
  combined.process(validate=False)
  scene.add_geometry(combined,geom_name=name,node_name=name)
  categories[name]=len(combined.faces)
 binary=scene.export(file_type='glb',include_normals=False)
 out=HERE/'city001_reference_blockout_v2.glb';out.write_bytes(binary)
 return {'bytes':len(binary),'meshes':len(scene.geometry),'triangles':sum(len(x.faces) for x in scene.geometry.values()),'layers':len(set(k.split('_')[0] for k in categories)),'longestParts':sorted(categories.items(),key=lambda x:-x[1])[:12]}


def schematic_plan(m):
 from matplotlib import pyplot as plt
 plt.rcParams['font.family']='DejaVu Sans'
 fig,ax=plt.subplots(figsize=(16,10.66),dpi=110)
 ax.set_facecolor('#0a4a71')
 ax.contourf(U,V,heights,levels=[-5,0,3,6,10,16,25,40],colors=['#145e88','#5c9063','#6f965b','#8a9974','#999c88','#aea598','#c6bdb0'],alpha=.98)
 ax.contour(U,V,heights,levels=[0,3,6,10,16,25],colors='k',alpha=.28,linewidths=.5)
 for river in RIVERS:
  p=np.array(river['points']);ax.plot(p[:,0],p[:,1],lw=7,color='#2ba8d2',alpha=.9,zorder=5)
 for q in QUARRIES:
  from matplotlib.patches import Ellipse
  ax.add_patch(Ellipse(q['center'],q['radius'][0]*2,q['radius'][1]*2,ec='#eab55b',fc='#be9155',alpha=.52,lw=2,zorder=6))
 for r in ROADS:
  pts=np.array(r['pts']);ax.plot(pts[:,0],pts[:,1],lw=7 if r['type']=='arterial' else 5,color='#d9ceac',alpha=.9,zorder=7)
  ax.plot(pts[:,0],pts[:,1],lw=4 if r['type']=='arterial' else 2.7,color='#3d4950',alpha=.95,zorder=8)
 from matplotlib.patches import Polygon as Pg
 for zone in RESIDENTIAL:ax.add_patch(Pg(zone['polygon'],closed=True,facecolor='#c1c39b',edgecolor='#ecebd3',hatch='..',alpha=.4,zorder=3))
 from matplotlib.lines import Line2D
 for i,s in enumerate(m['sites'],1):
  u,v=s['referencePixel'];color=colors[s['kind']];ax.scatter([u],[v],s=390,c=color,edgecolor='white',linewidths=2,zorder=10)
  ax.text(u,v,str(i),ha='center',va='center',fontsize=11,fontweight='bold',color='black',zorder=11)
 for p in BRIDGES:ax.scatter([p['p'][0]],[p['p'][1]],marker='D',s=70,c='#e5c279',zorder=12)
 ax.set_xlim(0,W);ax.set_ylim(H,0);ax.set_aspect('equal');ax.set_xticks(np.arange(0,W+1,256));ax.set_yticks(np.arange(0,H+1,128));ax.grid(alpha=.13)
 ax.set_title('DAILYCORP / CITY 001 — REFERENCE-ALIGNED 3D BLOCKOUT V2: TERRAIN + ROADS + 13 SITES',pad=12,fontsize=16)
 ax.set_xlabel('image reference X (0..1536)');ax.set_ylabel('image reference Y (0..1024)')
 fig.tight_layout();fig.savefig(HERE/'city001_topology_heights_v2.png',facecolor='#e3e7e5');plt.close(fig)

if __name__=='__main__':
 m=write_manifest()
 if SOURCE.is_file(): annotate(Image.open(SOURCE),m)
 else: print('Reference PNG missing: overlay skipped; GLB/JSON still generated')
 schematic_plan(m); data=build();glb=export_glb();m['geometryStats']={**data,**glb}
 for site in m['sites']:
  site['world'][1]=round(surface_at(site['world'][0],site['world'][2])+.2,3)
 mpath=HERE/'city001_blockout_v2.json';mpath.write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding='utf-8')
 print(json.dumps({'stats':m['geometryStats'],'outputs':[p.name for p in HERE.glob('*') if p.name!='build_blockout_v2.py']},indent=2))