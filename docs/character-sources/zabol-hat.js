/** A closed, sculpted tricorn for Żabol. Local Y=0 is the tabletop; +Z is his face. */
export function createZabolHat(THREE) {
  const hat = new THREE.Group();
  hat.name = 'zabol-volumetric-tricorn';

  const leather = new THREE.MeshStandardMaterial({ color: 0x17202b, roughness: 0.68, metalness: 0.04 });
  const crownLeather = new THREE.MeshStandardMaterial({ color: 0x202735, roughness: 0.71, metalness: 0.025 });
  const gold = new THREE.MeshStandardMaterial({ color: 0xe9af3d, roughness: 0.30, metalness: 0.73 });
  const darkGold = new THREE.MeshStandardMaterial({ color: 0x996324, roughness: 0.46, metalness: 0.65 });
  const bandLeather = new THREE.MeshStandardMaterial({ color: 0x76331b, roughness: 0.62, metalness: 0.04 });
  const seamMaterial = new THREE.MeshStandardMaterial({ color: 0x4f432d, roughness: 0.8, metalness: 0.05 });

  const addMesh = (geometry, material, parent = hat) => {
    const mesh = new THREE.Mesh(geometry, material);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    parent.add(mesh);
    return mesh;
  };
  const tube = (points, radius, material, closed = false, segments = 100, parent = hat) => {
    const curve = points instanceof THREE.Curve ? points : new THREE.CatmullRomCurve3(points, closed, 'centripetal');
    return addMesh(new THREE.TubeGeometry(curve, segments, radius, 10, closed), material, parent);
  };
  const v3 = (x, y, z) => new THREE.Vector3(x, y, z);

  // The crown has its own complete elliptical dome: the hat remains a hat when
  // the camera moves behind or above Żabol, rather than exposing a front panel.
  const crownProfile = [
    [0, 4.57], [1.39, 4.57], [1.48, 4.66], [1.49, 4.84],
    [1.45, 5.04], [1.34, 5.27], [1.13, 5.48], [.83, 5.65],
    [.46, 5.76], [.12, 5.79], [0, 5.79],
  ].map(([r, y]) => new THREE.Vector2(r, y));
  const crown = addMesh(new THREE.LatheGeometry(crownProfile, 80), crownLeather);
  crown.scale.z = .65;
  crown.position.z = -.025;

  const bandProfile = [
    [1.405, 4.52], [1.49, 4.52], [1.51, 4.58], [1.50, 4.73],
    [1.47, 4.79], [1.40, 4.76], [1.405, 4.52],
  ].map(([r, y]) => new THREE.Vector2(r, y));
  const band = addMesh(new THREE.LatheGeometry(bandProfile, 80), bandLeather);
  band.scale.z = .65;

  // Continuous outer lip: the tall front fold is joined to two sweeping side
  // wings and a genuine rear fold. Its silhouette follows the illustrated hat.
  const outer = new THREE.CatmullRomCurve3([
    v3(0, 6.27, 1.045), v3(.73, 6.03, 1.065),
    v3(1.33, 5.35, 1.015), v3(1.94, 5.31, .73),
    v3(2.60, 4.77, .02), v3(2.22, 4.65, -.69),
    v3(1.46, 5.07, -1.085), v3(.65, 5.57, -1.36),
    v3(0, 5.80, -1.50), v3(-.65, 5.57, -1.36),
    v3(-1.46, 5.07, -1.085), v3(-2.22, 4.65, -.69),
    v3(-2.60, 4.77, .02), v3(-1.94, 5.31, .73),
    v3(-1.33, 5.35, 1.015), v3(-.73, 6.03, 1.065),
  ], true, 'centripetal');
  const surfacePoint = (u, t) => {
    const wrapped = ((u % 1) + 1) % 1;
    const angle = wrapped * Math.PI * 2;
    const edge = outer.getPoint(wrapped);
    const inner = v3(Math.sin(angle) * 1.43, 4.61, Math.cos(angle) * .91);
    const p = inner.clone().lerp(edge, t);
    p.y = inner.y + (edge.y - inner.y) * (.16 * t + .84 * t * t);
    // A convex leather belly gives the raised brim a soft, upholstered roll.
    const bow = Math.sin(Math.PI * t) * .18;
    p.x += Math.sin(angle) * bow;
    p.z += Math.cos(angle) * bow;
    return p;
  };
  const surfaceNormal = (u, t) => {
    const tangent = surfacePoint(u + .0001, t).sub(surfacePoint(u - .0001, t));
    const radial = surfacePoint(u, Math.min(1, t + .0001)).sub(surfacePoint(u, Math.max(0, t - .0001)));
    return radial.cross(tangent).normalize();
  };
  const around = 176;
  const across = 24;
  const ringSize = across + 1;
  const surfaceCount = (around + 1) * ringSize;
  const vertices = [];
  const normals = [];
  const indices = [];
  const thickness = .065;
  for (const side of [1, -1]) {
    for (let i = 0; i <= around; i++) {
      for (let j = 0; j <= across; j++) {
        const u = i / around;
        const t = j / across;
        const n = surfaceNormal(u, t);
        const p = surfacePoint(u, t).addScaledVector(n, thickness * side);
        vertices.push(p.x, p.y, p.z);
        normals.push(n.x * side, n.y * side, n.z * side);
      }
    }
  }
  for (let i = 0; i < around; i++) {
    for (let j = 0; j < across; j++) {
      const a = i * ringSize + j;
      const b = a + ringSize;
      indices.push(a, a + 1, b, b, a + 1, b + 1);
      const c = a + surfaceCount;
      const d = b + surfaceCount;
      indices.push(c, d, c + 1, d, d + 1, c + 1);
    }
  }
  // The inner and outer edges are closed with actual leather walls. The rolled
  // gold binding rounds the join, while the underside has its own real surface.
  for (const edge of [0, across]) {
    for (let i = 0; i < around; i++) {
      const a = i * ringSize + edge;
      const b = (i + 1) * ringSize + edge;
      if (edge === across) indices.push(a, b, a + surfaceCount, b, b + surfaceCount, a + surfaceCount);
      else indices.push(a, a + surfaceCount, b, b, a + surfaceCount, b + surfaceCount);
    }
  }
  const brimGeometry = new THREE.BufferGeometry();
  brimGeometry.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
  brimGeometry.setAttribute('normal', new THREE.Float32BufferAttribute(normals, 3));
  brimGeometry.setIndex(indices);
  brimGeometry.computeBoundingSphere();
  addMesh(brimGeometry, leather);

  const outerBinding = [];
  const innerBinding = [];
  const insetStitch = [];
  for (let i = 0; i < 176; i++) {
    const u = i / 176;
    outerBinding.push(surfacePoint(u, 1));
    innerBinding.push(surfacePoint(u, 0));
    const p = surfacePoint(u, .956);
    p.addScaledVector(surfaceNormal(u, .956), -thickness - .006);
    insetStitch.push(p);
  }
  tube(outerBinding, .077, darkGold, true, 224);
  // The narrow bright ridge is offset to the outside of the rolled binding.
  const highlightBinding = outerBinding.map((p, i) =>
    p.clone().addScaledVector(surfaceNormal(i / 176, 1), -.031));
  tube(highlightBinding, .048, gold, true, 224);
  tube(innerBinding, .034, darkGold, true, 176);
  tube(insetStitch, .009, seamMaterial, true, 224);

  // Raised gold anchor. All components have depth, including the flukes and the
  // ring, so the emblem catches real light and casts a shadow on the leather.
  const anchor = new THREE.Group();
  anchor.name = 'raised-gold-anchor';
  anchor.position.set(0, 5.51, 1.255);
  hat.add(anchor);
  const extrude = (shape, depth = .072, material = gold) => {
    const geo = new THREE.ExtrudeGeometry(shape, {
      depth, bevelEnabled: true, bevelSegments: 3,
      bevelThickness: .015, bevelSize: .014, curveSegments: 20, steps: 1,
    });
    return addMesh(geo, material, anchor);
  };
  const shaft = new THREE.Shape();
  shaft.moveTo(-.049, .43);
  shaft.lineTo(.049, .43);
  shaft.lineTo(.054, -.34);
  shaft.lineTo(.072, -.44);
  shaft.lineTo(0, -.51);
  shaft.lineTo(-.072, -.44);
  shaft.lineTo(-.054, -.34);
  shaft.closePath();
  extrude(shaft);
  const stock = new THREE.Shape();
  stock.moveTo(-.30, .275);
  stock.quadraticCurveTo(-.33, .255, -.31, .19);
  stock.lineTo(-.27, .17);
  stock.lineTo(-.23, .20);
  stock.lineTo(.23, .20);
  stock.lineTo(.27, .17);
  stock.lineTo(.31, .19);
  stock.quadraticCurveTo(.33, .255, .30, .275);
  stock.lineTo(.25, .25);
  stock.lineTo(-.25, .25);
  stock.closePath();
  extrude(stock, .080);
  const arms = new THREE.Shape();
  arms.moveTo(0, -.51);
  arms.bezierCurveTo(-.12, -.40, -.43, -.38, -.49, -.12);
  arms.lineTo(-.58, -.17);
  arms.lineTo(-.50, .10);
  arms.lineTo(-.29, -.075);
  arms.lineTo(-.39, -.09);
  arms.bezierCurveTo(-.33, -.27, -.12, -.285, 0, -.33);
  arms.bezierCurveTo(.12, -.285, .33, -.27, .39, -.09);
  arms.lineTo(.29, -.075);
  arms.lineTo(.50, .10);
  arms.lineTo(.58, -.17);
  arms.lineTo(.49, -.12);
  arms.bezierCurveTo(.43, -.38, .12, -.40, 0, -.51);
  arms.closePath();
  extrude(arms, .075);
  const ring = addMesh(new THREE.TorusGeometry(.102, .033, 12, 40), gold, anchor);
  ring.position.set(0, .493, .046);
  const rivet = addMesh(new THREE.SphereGeometry(.032, 12, 8), darkGold, anchor);
  rivet.scale.z = .46;
  rivet.position.set(0, .235, .098);

  // Restrained crown seams describe the back and side volume without textures.
  for (const angle of [Math.PI * .45, Math.PI, Math.PI * 1.55]) {
    const pts = [
      [1.47, 4.80], [1.40, 5.12], [1.10, 5.50], [.58, 5.75], [.08, 5.795],
    ].map(([r, y]) => v3(Math.sin(angle) * r, y, Math.cos(angle) * r * .65 - .025));
    tube(pts, .012, seamMaterial, false, 32);
  }
  return hat;
}
