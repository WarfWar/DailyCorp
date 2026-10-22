#!/usr/bin/env python3
"""DailyCorp City001 procedural 3D scene. True meshes, no painted panorama."""
import json, math, random
from pathlib import Path
import numpy as np
import trimesh

ROOT=Path(__file__).parent
R=random.Random(1001)
COLORS={
 'sea': '#176793','foam':'#74c4d6','river':'#36a9ce','grass':'#4f9060','woodland':'#386947',
 'ridge':'#7e8280','stone':'#9c9585','sand':'#cdb67d','road':'#474d55','road_trim':'#b6ac87',
 'roof_red':'#9c4e42','roof_blue':'#3c6f9d','building':'#ded3bf','industrial':'#bcc4c5',
 'asphalt':'#51565c','mine':'#cb9b5b','tree_dark':'#245940','tree_light':'#337755',
 'market':'#c04f3f','science':'#edf0e6','power':'#a9bac5','accent':'#e2b35d'
}

def rgb(hex):return np.array([int(hex[i:i+2],16) for i in (1,3,5)]+[255],dtype=np.uint8)

def elevation(x,z):
    # Coastline west/south; inland mountains to north and east. Surface is
    # deterministic: no PNG projection or overlay.
    hills=1.15 + .48*math.sin(x*.17)*math.cos(z*.13)
    north=max(0,(-z-21)/14)**2*8.0
    east=max(0,(x-30)/13)**2*6.0
    west=max(0,(-x-28)/11)**2*3.0
    # lower ground around the central city and port
    center=4.4*math.exp(-((x-1)**2+(z-0)**2)/1200)
    y=max(.75,hills+north+east+west-center*.14)
    if z>31-2.4*math.sin(x*.085) or x< -41.5+2.3*math.cos(z*.17):
        y = -1.35
    return y

def box(size,location,color):
    m=trimesh.creation.box(extents=size)
    m.apply_translation(location)
    m.visual.vertex_colors=np.tile(rgb(COLORS.get(color,color)),(len(m.vertices),1))
    return m

def cone(radius,height,location,color,sections=6):
    m=trimesh.creation.cone(radius,height,sections=sections)
    # cone points positive Z by default: rotate +Z to +Y
    M=trimesh.transformations.rotation_matrix(-math.pi/2,[1,0,0])
    m.apply_transform(M);m.apply_translation(location)
    m.visual.vertex_colors=np.tile(rgb(COLORS.get(color,color)),(len(m.vertices),1))
    return m

def cylinder(radius,height,location,color,sections=9):
    m=trimesh.creation.cylinder(radius,height,sections=sections)
    m.apply_transform(trimesh.transformations.rotation_matrix(-math.pi/2,[1,0,0]))
    m.apply_translation(location)
    m.visual.vertex_colors=np.tile(rgb(COLORS.get(color,color)),(len(m.vertices),1))
    return m

def poly_roof(w,d,center,height,color):
    x,y,z=center
    verts=[[x-w/2,y,z-d/2],[x+w/2,y,z-d/2],[x+w/2,y,z+d/2],[x-w/2,y,z+d/2],
           [x,y+height,z-d/2],[x,y+height,z+d/2]]
    faces=[[0,1,4],[3,5,2],[0,4,5],[0,5,3],[1,2,5],[1,5,4]]
    m=trimesh.Trimesh(vertices=verts,faces=faces,process=False)
    m.visual.vertex_colors=np.tile(rgb(COLORS[color]),(len(m.vertices),1))
    return m

def elevation_base(x,z):return max(1.2,elevation(x,z))

objects=[
 {'kind':'MINE','ordinal':0,'id':'mine_1','name':'Шахта 1','x':32,'z':-26,'footprint':[10,9],'state':'FOR_SALE'},
 {'kind':'MINE','ordinal':1,'id':'mine_2','name':'Шахта 2','x':6,'z':-35,'footprint':[10,9],'state':'FOR_SALE'},
 {'kind':'MINE','ordinal':2,'id':'mine_3','name':'Шахта 3','x':35,'z':13,'footprint':[10,9],'state':'FOR_SALE'},
 {'kind':'FACTORY','ordinal':0,'id':'factory_1','name':'Завод 1','x':-13,'z':-5,'footprint':[10,9]},
 {'kind':'FACTORY','ordinal':1,'id':'factory_2','name':'Завод 2','x':-24,'z':9,'footprint':[10,9]},
 {'kind':'WAREHOUSE','ordinal':0,'id':'warehouse_1','name':'Склад 1','x':18,'z':19,'footprint':[8,7]},
 {'kind':'WAREHOUSE','ordinal':1,'id':'warehouse_2','name':'Склад 2','x':-6,'z':9,'footprint':[8,7]},
 {'kind':'WAREHOUSE','ordinal':2,'id':'warehouse_3','name':'Склад 3','x':-35,'z':17,'footprint':[8,7]},
 {'kind':'WAREHOUSE','ordinal':3,'id':'warehouse_4','name':'Склад 4','x':-19,'z':24,'footprint':[8,7]},
 {'kind':'RESEARCH','ordinal':0,'id':'research_1','name':'Научный центр','x':-30,'z':-26,'footprint':[9,9]},
 {'kind':'MUNICIPAL','ordinal':0,'id':'municipal_1','name':'Мэрия','x':2,'z':-19,'footprint':[8,7]},
 {'kind':'ENERGY','ordinal':0,'id':'energy_1','name':'Электростанция','x':24,'z':-7,'footprint':[10,10]},
 {'kind':'MARKET','ordinal':0,'id':'market_1','name':'Рынок','x':3,'z':-2,'footprint':[8,7]},
]
roads=[
 [[-42,-18],[-30,-18],[-14,-18],[3,-19],[21,-20],[40,-17]],
 [[-41,-3],[-26,-3],[-14,-5],[3,-7],[23,-7],[40,-7]],
 [[-40,12],[-24,10],[-5,9],[15,10],[36,13]],
 [[-38,26],[-22,24],[-6,22],[17,20],[37,22]],
 [[-29,-32],[-30,-25],[-27,-13],[-25,0],[-24,9],[-20,24]],
 [[-12,-34],[-11,-24],[-13,-6],[-9,9],[-7,23]],
 [[5,-39],[5,-32],[2,-20],[1,-9],[3,0],[4,12],[6,28]],
 [[24,-34],[27,-24],[25,-13],[23,-7],[19,8],[18,19],[18,29]],
 [[38,-28],[34,-24],[30,-17],[34,0],[36,13]],
 [[-42,-1],[-38,5],[-34,13],[-30,22]],
 [[-30,-28],[-17,-23],[-3,-14],[9,-4],[22,8],[34,18]],
]

manifest={
 'schema':'dailycorp.city3d.v1','cityId':1,'reference':'approved mirrored City 001',
 'units':'scene_units','world':{'width':96,'depth':88,'seaHeight':0.0,'grid':[36,34],
 'coordinateSystem':'right-handed; X east, Y up, Z south'},
 'camera':{'projection':'perspective','azimuth':-40,'elevation':47,'distance':142,'target':[0,2,0],
           'fovDegrees':44,'minDistance':70,'maxDistance':245},
 'sites':[{**o, 'y':round(elevation_base(o['x'],o['z']),3)} for o in objects], 'roads':roads,
 'environment':{'coast':'west_and_south','mountains':'north_and_east','river':'right-center',
 'bridges':3,'forestCountTarget':300,'harbor':'south-west'},
 'binding':{'mode':'BuildingKind+ordinal','idSource':'City.lots (saved game)',
 'siteCount':13,'legacySavePolicy':'do not mutate saved Lot ids'},
 'renderHints':{'materialStyle':'stylized low-poly industrial, vivid turquoise water',
 'targetFPS':30,'textureDependency':'none','renderQuality':'prototype'}
}
(ROOT/'city001_scene.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')

scene=trimesh.Scene()
base_groups={}

def add(group,mesh):
    if group not in base_groups:base_groups[group]=[]
    base_groups[group].append(mesh)

# heightfield 68x64 vertices; adjacent faces colored by climate
xs=np.linspace(-48,48,69);zs=np.linspace(-44,44,65)
vertices=[]
for z in zs:
 for x in xs:vertices.append([x,elevation(float(x),float(z)),z])
faces=[]
for iz in range(len(zs)-1):
 for ix in range(len(xs)-1):
  a=iz*len(xs)+ix;b=a+1;c=a+len(xs);d=c+1
  faces.extend([[a,c,b],[b,c,d]])
land=trimesh.Trimesh(vertices=np.array(vertices),faces=faces,process=False)
vc=[]
for x,y,z in land.vertices:
 if y<0: palette='sand'
 elif y>9:palette='ridge'
 elif y>4.8:palette='stone'
 elif z< -20:palette='woodland'
 else:palette='grass'
 vc.append(rgb(COLORS[palette]))
land.visual.vertex_colors=np.array(vc)
scene.add_geometry(land,node_name='terrain_mesh',geom_name='terrain_geometry')
add('water',box([125,.18,116],[0,-.34,1],'sea'))

# rocky coast chunks and foamy bright pockets
for idx in range(170):
 x=R.uniform(-47,47);z=R.uniform(-42,42)
 y=elevation(x,z)
 if y>0 and (z>27 or x<-36 or (x>32 and R.random()>.55)):
  h=R.uniform(.65,2.5)
  add('rock_coast',cone(R.uniform(.5,1.4),h,[x,y+h/2-.45,z],'stone',sections=5))
for n in range(45):
 x=R.uniform(-42,40);z=R.uniform(32,43)
 add('sea_foam',box([R.uniform(.6,2),.05,R.uniform(.11,.25)],[x,.03,z],'foam'))

# ribbons with vertices fit terrain; 3d roads are their own meshes
for ri,poly in enumerate(roads):
 for (x0,z0),(x1,z1) in zip(poly,poly[1:]):
  distance=math.hypot(x1-x0,z1-z0)
  for seg in range(max(1,math.ceil(distance/1.8))):
   a=seg/max(1,math.ceil(distance/1.8));b=(seg+1)/max(1,math.ceil(distance/1.8))
   xa=x0+(x1-x0)*a;za=z0+(z1-z0)*a;xb=x0+(x1-x0)*b;zb=z0+(z1-z0)*b
   dx=xb-xa; dz=zb-za;length=math.hypot(dx,dz)
   if length<.02:continue
   nx=-dz/length;nz=dx/length
   ya=max(1.44,elevation(xa,za)+.13);yb=max(1.44,elevation(xb,zb)+.13)
   for width,gname,col in [(2.25,'road_edges','road_trim'),(1.96,'road_asphalt','road')]:
    pts=np.array([[xa+nx*width/2,ya,za+nz*width/2],[xa-nx*width/2,ya,za-nz*width/2],
                  [xb+nx*width/2,yb,zb+nz*width/2],[xb-nx*width/2,yb,zb-nz*width/2]])
    m=trimesh.Trimesh(vertices=pts,faces=[[0,1,2],[1,3,2]],process=False)
    m.visual.vertex_colors=np.tile(rgb(COLORS[col]),(4,1))
    add(gname,m)

# winding blue river, flow below road bridge segments
river=[]
for zz in np.arange(-43,33,.9):
 xx=13.8+3*math.sin(zz*.16)+1.3*math.sin(zz*.43)
 river.append([float(xx),float(zz)])
for (x0,z0),(x1,z1) in zip(river,river[1:]):
  dx=x1-x0;dz=z1-z0;ll=math.hypot(dx,dz);nx=-dz/ll;nz=dx/ll
  y=max(.22,(elevation(x0,z0)+elevation(x1,z1))/2+.08)
  verts=np.array([[x0+nx*.9,y,z0+nz*.9],[x0-nx*.9,y,z0-nz*.9],
                  [x1+nx*.9,y,z1+nz*.9],[x1-nx*.9,y,z1-nz*.9]])
  m=trimesh.Trimesh(vertices=verts,faces=[[0,1,2],[1,3,2]],process=False)
  m.visual.vertex_colors=np.tile(rgb(COLORS['river']),(4,1));add('river',m)

# clear each site platform, leaving original terrain underneath; each is its own glTF node
kindcolors={'MINE':'mine','FACTORY':'industrial','WAREHOUSE':'roof_blue','RESEARCH':'science',
'MUNICIPAL':'building','ENERGY':'power','MARKET':'market'}
for site in objects:
 kind=site['kind'];x=site['x'];z=site['z'];w,d=site['footprint'];y=elevation_base(x,z)
 name='LOT_'+kind+'_'+str(site['ordinal'])
 components=[]
 components.append(box([w+.7,.36,d+.7],[x,y+.12,z],'sand'))
 if kind=='MINE':
  # excavated terraced pit, quarry machinery, headframe
  components.append(box([w*.84,.55,d*.66],[x,y+.53,z],'stone'))
  components.append(box([w*.6,.30,d*.45],[x,y+.82,z],'mine'))
  for k in range(4):
   components.append(box([.35,2.5,.4],[x-2+k*1.4,y+2.15,z-1.8],'stone'))
  components.append(box([5.4,.35,.6],[x+.1,y+3.3,z-1.8],'accent'))
  components.append(cylinder(.36,5.8,[x+3,y+3.2,z+2.3],'industrial'))
  components.append(box([1.8,1.4,1.8],[x-3.0,y+1.3,z+2.5],'industrial'))
 elif kind=='FACTORY':
  components.append(box([w*.78,3.2,d*.67],[x,y+1.94,z],'industrial'))
  components.append(poly_roof(w*.8,d*.7,[x,y+3.54,z],1,'roof_red'))
  components.append(box([w*.27,2.4,d*.36],[x-2.9,y+1.3,z+1.8],'roof_blue'))
  for j in range(2):
   components.append(cylinder(.4,6.7,[x+2.6+j*1.15,y+3.6,z-1.8],'stone'))
   components.append(cylinder(.52,.30,[x+2.6+j*1.15,y+7.05,z-1.8],'roof_red'))
 elif kind=='WAREHOUSE':
  components.append(box([w*.82,2.8,d*.78],[x,y+1.57,z],'industrial'))
  components.append(poly_roof(w*.87,d*.82,[x,y+2.97,z],1.0,'roof_blue'))
  for j in range(3):components.append(box([1,.9,.14],[x+(j-1)*1.9,y+1.4,z+d*.41],'roof_red'))
 elif kind=='MUNICIPAL':
  components.append(box([w*.66,4.5,d*.63],[x,y+2.43,z],'science'))
  components.append(poly_roof(w*.7,d*.7,[x,y+4.7,z],1.6,'roof_blue'))
  components.append(cylinder(1.3,1.2,[x,y+5.5,z],'science'))
  components.append(cone(1.6,1.4,[x,y+6.55,z],'roof_blue',sections=9))
  for j in (-2.2,-.75,.75,2.2):components.append(cylinder(.2,3.2,[x+j,y+2.5,z+d*.34],'building'))
 elif kind=='RESEARCH':
  components.append(box([w*.68,3.5,d*.65],[x,y+1.9,z],'science'))
  components.append(cone(2.15,2.3,[x-1,y+5.0,z],'roof_blue',sections=12))
  components.append(cylinder(1.1,2.3,[x+2,y+4.9,z+1.2],'science'))
  components.append(cone(1.3,1,[x+2,y+6.3,z+1.2],'roof_blue',sections=10))
  components.append(cylinder(2.0,.24,[x-2.4,y+.6,z+3],'river'))
 elif kind=='ENERGY':
  components.append(box([w*.7,4.0,d*.64],[x,y+2.2,z],'industrial'))
  components.append(box([w*.72,.35,d*.7],[x,y+4.4,z],'roof_blue'))
  for j in range(3):
   components.append(cylinder(.58,8.5,[x-2.2+j*2.3,y+4.5,z-1.5],'stone'))
   components.append(cylinder(.77,.35,[x-2.2+j*2.3,y+8.9,z-1.5],'roof_red'))
 elif kind=='MARKET':
  for i in range(3):
   for j in range(2):
    bx=x+(i-1)*2.45; bz=z+(j-.5)*3.3
    components.append(box([2.1,1.2,2.4],[bx,y+.8,bz],'building'))
    components.append(poly_roof(2.5,2.8,[bx,y+1.45,bz],.8,'market' if (i+j)%2 else 'accent'))
 scene.add_geometry(trimesh.util.concatenate(components),node_name=name,geom_name=name)

# residential quarters in empty spaces (do not overlap landmarks or roads)
houses=[]
for i in range(220):
 x=R.uniform(-37,36);z=R.uniform(-29,27)
 if min(math.hypot(x-o['x'],z-o['z']) for o in objects)<8.5:continue
 if min(min(math.hypot(x-u,z-v) for u,v in route) for route in roads)<1.5:continue
 if x>20 and z<-8:continue
 if elevation(x,z)>6:continue
 yy=elevation_base(x,z);w=R.uniform(1.6,2.3);d=R.uniform(1.8,2.4);hh=R.uniform(1.5,3.4)
 houses.append(box([w,hh,d],[x,yy+hh/2,z],'building'))
 houses.append(poly_roof(w*1.15,d*1.1,[x,yy+hh,z],.7,'roof_red' if i%3 else 'roof_blue'))
add('town_houses',trimesh.util.concatenate(houses))

# Forest clusters avoid roads and important buildings. Very low poly 5-sided cones.
for t in range(470):
 x=R.uniform(-47,47);z=R.uniform(-40,34)
 if elevation(x,z)<0 or elevation(x,z)>13:continue
 if min(math.hypot(x-o['x'],z-o['z']) for o in objects)<8.5:continue
 if min(min(math.hypot(x-u,z-v) for u,v in route) for route in roads)<2.2:continue
 if R.random()<.2 and z>5:continue
 y=elevation_base(x,z)
 height=R.uniform(1.6,4.1)
 add('pine_trunks',cylinder(.10,height*.35,[x,y+height*.16,z],'stone',sections=5))
 add('pine_canopies',cone(height*.23,height*.9,[x,y+height*.5,z],
                         'tree_dark' if t%3 else 'tree_light',sections=5))

# Stone mountain pinnacles left/right ridgeline
for n in range(65):
 x=R.choice([R.uniform(-47,47),R.uniform(27,46)])
 z=R.uniform(-43,-29) if R.random()<.64 else R.uniform(-40,30)
 if min(math.hypot(x-o['x'],z-o['z']) for o in objects)<7:continue
 y=elevation_base(x,z)
 hh=R.uniform(2.3,8.8)
 add('mountain_spires',cone(hh*.32,hh,[x,y+hh*.48,z],'ridge',sections=5))

# cranes and port at south-west sea
for px,pz in [(-34,32),(-23,33),(-14,31)]:
 y=1.2
 add('port_docks',box([9,.9,3],[px,0.45,pz],'industrial'))
 add('port_cranes',box([.42,7,.42],[px+1,y+3,pz-1],'accent'))
 add('port_cranes',box([5,.25,.38],[px+3.2,y+6.3,pz-1],'accent'))
 add('port_cranes',box([.22,2.4,.25],[px+5,y+5.1,pz-1],'accent'))
for x,z in [(-30,38),(-18,36)]:
 add('boats',box([2,.6,4],[x,.18,z],'science'))
 add('boats',box([1,.75,2.2],[x,.72,z],'roof_blue'))

# group meshes for small GPU draw call count
for group,meshes in base_groups.items():
 combined=trimesh.util.concatenate(meshes)
 scene.add_geometry(combined,node_name=group,geom_name=group)

out=ROOT/'city001_v0_1.glb'
scene.export(out,file_type='glb')
geo=sum(len(g.faces) for g in scene.geometry.values());nv=sum(len(g.vertices) for g in scene.geometry.values())
report={'sceneNodes':len(scene.graph.nodes),'geometryMeshes':len(scene.geometry),'vertices':nv,'triangles':geo,'glbBytes':out.stat().st_size,
'sites':{k:len([a for a in objects if a['kind']==k]) for k in sorted(set(o['kind'] for o in objects))},
'origin':'procedural 3D meshes, NO PNG panoramas'}
(ROOT/'build_report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False,indent=2))