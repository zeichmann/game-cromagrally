import {createZabolOutfit} from './zabol-outfit.js';
import {createZabolHat} from './zabol-hat.js';

/** Sculpted, fully dimensional Żabol. Origin is the tabletop; forward is +Z. */
export function createZabolPirate(THREE) {
  const root = new THREE.Group();
  root.name = 'Zabol_pirate_seated';
  const sphere = new THREE.SphereGeometry(1, 40, 28);
  const skin = new THREE.MeshPhysicalMaterial({color:0x91ac30,roughness:.43,clearcoat:.18,clearcoatRoughness:.38});
  const lightSkin = new THREE.MeshPhysicalMaterial({color:0xb9c843,roughness:.43,clearcoat:.16});
  const darkSkin = new THREE.MeshStandardMaterial({color:0x617b20,roughness:.56});
  const cream = new THREE.MeshPhysicalMaterial({color:0xfff1d1,roughness:.20,clearcoat:.7,clearcoatRoughness:.14});
  const black = new THREE.MeshPhysicalMaterial({color:0x100c08,roughness:.13,clearcoat:1,clearcoatRoughness:.08});
  const darkMouth = new THREE.MeshStandardMaterial({color:0x3d150e,roughness:.72,side:THREE.DoubleSide});
  const tongueMaterial = new THREE.MeshPhysicalMaterial({color:0xdd7337,roughness:.44,clearcoat:.15});
  const tongueCrease = new THREE.MeshStandardMaterial({color:0x9b4327,roughness:.60});
  const glint = new THREE.MeshBasicMaterial({color:0xfff8df,toneMapped:false});
  function ellipsoid(name, material, position, size, parent=root) {
    const mesh = new THREE.Mesh(sphere, material);
    mesh.name=name;mesh.position.set(...position);mesh.scale.set(...size);parent.add(mesh);
    mesh.castShadow=true;mesh.receiveShadow=true;return mesh;
  }
  function tube(name, points, radius, material, closed=false, parent=root) {
    const curve=new THREE.CatmullRomCurve3(points.map(p=>Array.isArray(p)?new THREE.Vector3(...p):p),closed,'centripetal');
    const mesh=new THREE.Mesh(new THREE.TubeGeometry(curve,Math.max(24,points.length*3),radius,8,closed),material);
    mesh.name=name;mesh.castShadow=true;mesh.receiveShadow=true;parent.add(mesh);return mesh;
  }

  const outfit=createZabolOutfit(THREE);root.add(outfit);
  ellipsoid('throat',lightSkin,[0,2.00,.16],[.89,.60,.63]);

  // A complete ellipsoidal skull with an actual opening cut into its front.
  // The opening's boundary is sampled exactly, then closed by a recessed bowl.
  const head={x:1.79,y:1.31,z:1.09,cy:3.35,cz:.27};
  const mouth={x:1.33,y:.46,cy:2.76};
  const rows=[];
  for(let i=0;i<=80;i++)rows.push(head.cy-head.y+2*head.y*i/80);
  for(let i=0;i<=40;i++)rows.push(mouth.cy-mouth.y+2*mouth.y*i/40);
  const levels=[...new Set(rows.map(v=>v.toFixed(7)))].map(Number).sort((a,b)=>a-b);
  const segments=96,positions=[],normals=[],colors=[],indices=[];
  const dorsal=new THREE.Color(0x87a92b),belly=new THREE.Color(0xc1ce4a);
  for(const y of levels){
    const ring=Math.sqrt(Math.max(0,1-((y-head.cy)/head.y)**2));
    const rx=head.x*ring,rz=head.z*ring;
    const mouthLevel=(y-mouth.cy)/mouth.y;
    const mouthWidth=Math.abs(mouthLevel)<1?mouth.x*Math.sqrt(Math.max(0,1-mouthLevel*mouthLevel)):0;
    const cut=rx>0?Math.asin(Math.min(.985,mouthWidth/rx)):0;
    for(let j=0;j<=segments;j++){
      const angle=cut+(Math.PI*2-cut*2)*j/segments;
      const x=rx*Math.sin(angle),z=rz*Math.cos(angle);
      positions.push(x,y,head.cz+z);
      const normal=new THREE.Vector3(x/(head.x*head.x),(y-head.cy)/(head.y*head.y),z/(head.z*head.z)).normalize();
      normals.push(normal.x,normal.y,normal.z);
      const front=Math.max(0,Math.cos(angle));
      const lower=THREE.MathUtils.clamp((3.65-y)/1.5,0,1);
      const color=dorsal.clone().lerp(belly,front*lower*.8);
      const speckle=Math.sin(x*8+y*9+z*6)*Math.sin(x*6-y*7-z*8)*.012;
      color.offsetHSL(0,0,speckle);colors.push(color.r,color.g,color.b);
    }
  }
  for(let row=0;row<levels.length-1;row++)for(let col=0;col<segments;col++){
    const a=row*(segments+1)+col,b=a+segments+1;
    indices.push(a,a+1,b,a+1,b+1,b);
  }
  const skullGeometry=new THREE.BufferGeometry();
  skullGeometry.setAttribute('position',new THREE.Float32BufferAttribute(positions,3));
  skullGeometry.setAttribute('normal',new THREE.Float32BufferAttribute(normals,3));
  skullGeometry.setAttribute('color',new THREE.Float32BufferAttribute(colors,3));skullGeometry.setIndex(indices);
  const skullMaterial=new THREE.MeshPhysicalMaterial({vertexColors:true,roughness:.46,clearcoat:.16,clearcoatRoughness:.38});
  const skull=new THREE.Mesh(skullGeometry,skullMaterial);skull.name='sculpted_skull_with_open_mouth';root.add(skull);

  function mouthBoundary(angle){
    const x=mouth.x*Math.cos(angle),y=mouth.cy+mouth.y*Math.sin(angle);
    const ring=Math.sqrt(Math.max(.001,1-((y-head.cy)/head.y)**2));
    const z=head.cz+head.z*ring*Math.sqrt(Math.max(0,1-(x/(head.x*ring))**2));
    return new THREE.Vector3(x,y,z);
  }
  const rim=[];for(let i=0;i<96;i++){const point=mouthBoundary(i/96*Math.PI*2);point.z+=.025;rim.push(point);}
  tube('continuous_smile_lip',rim,.065,lightSkin,true);
  const cavityPositions=[],cavityIndices=[],radialSteps=12,circumference=96;
  for(let r=0;r<=radialSteps;r++)for(let j=0;j<=circumference;j++){
    const s=r/radialSteps,edge=mouthBoundary(j/circumference*Math.PI*2);
    cavityPositions.push(edge.x*s,mouth.cy+(edge.y-mouth.cy)*s,.24+(edge.z-.24)*Math.pow(s,2.1));
  }
  for(let r=0;r<radialSteps;r++)for(let j=0;j<circumference;j++){
    const a=r*(circumference+1)+j,b=a+circumference+1;cavityIndices.push(a,b,b+1,a,b+1,a+1);
  }
  const cavityGeometry=new THREE.BufferGeometry();cavityGeometry.setAttribute('position',new THREE.Float32BufferAttribute(cavityPositions,3));cavityGeometry.setIndex(cavityIndices);cavityGeometry.computeVertexNormals();
  const cavity=new THREE.Mesh(cavityGeometry,darkMouth);cavity.name='recessed_mouth_cavity';root.add(cavity);
  ellipsoid('lower_jaw',lightSkin,[0,2.20,.65],[1.01,.21,.60]);
  ellipsoid('tongue_left_lobe',tongueMaterial,[-.19,2.45,.80],[.32,.115,.25]);
  ellipsoid('tongue_right_lobe',tongueMaterial,[.19,2.45,.80],[.32,.115,.25]);
  tube('tongue_groove',[[0,2.552,.72],[0,2.557,.86],[0,2.51,1.01]],.012,tongueCrease);
  ellipsoid('upper_muzzle',lightSkin,[0,3.36,1.10],[.95,.185,.32]);
  for(const sign of [-1,1]){
    ellipsoid(`cheek_${sign}`,skin,[sign*1.31,2.98,.80],[.48,.43,.39]);
    const nostril=ellipsoid(`nostril_${sign}`,darkSkin,[sign*.275,3.43,1.417],[.047,.028,.014]);nostril.rotation.z=sign*.20;
    ellipsoid(`eye_turret_${sign}`,skin,[sign*.87,4.10,.64],[.70,.81,.65]);
    const eye=new THREE.Group();eye.name=`eye_${sign}`;eye.position.set(sign*.87,4.11,1.115);eye.rotation.x=.095;root.add(eye);
    ellipsoid('cream_eyeball',cream,[0,0,0],[.535,.625,.39],eye);
    const irisPositions=[],irisColors=[],irisIndices=[],irisRings=12,irisSegments=64;
    for(let r=0;r<=irisRings;r++)for(let a=0;a<=irisSegments;a++){
      const radius=r/irisRings,angle=a/irisSegments*Math.PI*2;
      irisPositions.push(Math.cos(angle)*.318*radius,Math.sin(angle)*.383*radius-.025,.354+.10*Math.sqrt(Math.max(0,1-radius*radius)));
      const streak=Math.sin(angle*41+radius*9)*.5+Math.sin(angle*67-radius*12)*.28;
      const base=new THREE.Color(radius>.88?0x563119:0xb57b32);base.offsetHSL(0,0,streak*.038*(radius>.4?1:.2));irisColors.push(base.r,base.g,base.b);
    }
    for(let r=0;r<irisRings;r++)for(let a=0;a<irisSegments;a++){const n=r*(irisSegments+1)+a,b=n+irisSegments+1;irisIndices.push(n,b,b+1,n,b+1,n+1);}
    const irisGeometry=new THREE.BufferGeometry();irisGeometry.setAttribute('position',new THREE.Float32BufferAttribute(irisPositions,3));irisGeometry.setAttribute('color',new THREE.Float32BufferAttribute(irisColors,3));irisGeometry.setIndex(irisIndices);irisGeometry.computeVertexNormals();
    const iris=new THREE.Mesh(irisGeometry,new THREE.MeshPhysicalMaterial({vertexColors:true,roughness:.24,clearcoat:.8,clearcoatRoughness:.13,side:THREE.DoubleSide}));iris.name='amber_iris';eye.add(iris);
    ellipsoid('large_black_pupil',black,[0,-.025,.453],[.205,.260,.057],eye);
    ellipsoid('large_eye_glint',glint,[-.071,.111,.503],[.060,.082,.020],eye);
    ellipsoid('small_eye_glint',glint,[.075,-.111,.505],[.024,.031,.012],eye);
    const upperLid=[];for(let i=0;i<=24;i++){const a=i/24*Math.PI;upperLid.push([Math.cos(a)*.548,Math.sin(a)*.638,.105]);}
    tube('upper_eye_lid',upperLid,.052,skin,false,eye);
    const lowerLid=[];for(let i=0;i<=24;i++){const a=Math.PI+i/24*Math.PI;lowerLid.push([Math.cos(a)*.538,Math.sin(a)*.620,.078]);}
    tube('lower_eye_lid',lowerLid,.030,lightSkin,false,eye);
  }

  const face=new THREE.Group();face.name='broad_frog_face';
  for(const child of [...root.children])if(child!==outfit)face.add(child);
  face.scale.set(1.10,1,1.02);root.add(face);

  // Plump, separately modelled fingers rest above the tabletop and attach to cuffs.
  for(const sign of [-1,1]){
    ellipsoid(`palm_${sign}`,skin,[sign*1.50,.20,1.76],[.43,.16,.45]);
    for(let finger=0;finger<3;finger++){
      const x=sign*(1.20+finger*.27),spread=(finger-1)*.065;
      const points=[[x,.18,1.80],[x+sign*spread,.15,2.06],[x+sign*spread*1.5,.135,2.28+(finger===1?.08:0)]];
      tube(`finger_${sign}_${finger}`,points,.12,lightSkin);
      ellipsoid(`fingertip_${sign}_${finger}`,lightSkin,points[2],[.123,.105,.14]);
      tube(`finger_fold_${sign}_${finger}`,[[x-sign*.07,.274,2.00],[x,.279,2.014],[x+sign*.06,.269,2.015]],.008,darkSkin);
    }
    tube(`thumb_${sign}`,[[sign*1.20,.19,1.56],[sign*.99,.155,1.72],[sign*.92,.14,1.91]],.14,skin);
    ellipsoid(`thumb_tip_${sign}`,lightSkin,[sign*.92,.14,1.91],[.14,.12,.15]);
  }
  root.add(createZabolHat(THREE));
  const normalizedGeometry=new Set();
  root.traverse(object=>{if(object.isMesh){object.castShadow=true;object.receiveShadow=true;const geo=object.geometry;if(normalizedGeometry.has(geo))return;normalizedGeometry.add(geo);const normal=geo.attributes.normal;if(normal){for(let i=0;i<normal.count;i++){const x=normal.getX(i),y=normal.getY(i),z=normal.getZ(i),length=Math.hypot(x,y,z);if(length<1e-10)normal.setXYZ(i,0,0,1);else normal.setXYZ(i,x/length,y/length,z/length);}normal.needsUpdate=true;}}});
  root.userData={character:'Żabol',representation:'sculpted-3d-mesh',forward:'+Z',origin:'tabletop',hasBack:true,hasChair:true};
  return root;
}
