/* Żabol's complete seated costume and chair. Units match chessboard squares.
 * The character faces +Z. The origin is the tabletop beneath the chest.
 * All visible details are solid meshes, so the costume can also be exported.
 */
export function createZabolOutfit(THREE) {
  const root = new THREE.Group();
  root.name = 'zabol-costume-and-chair';
  const costume = new THREE.Group();
  costume.name = 'zabol-tailored-captains-coat';
  const chair = new THREE.Group();
  chair.name = 'zabol-carved-captains-chair';
  root.add(chair, costume);

  const material = (name, color, roughness = .58, metalness = 0) => {
    const m = new THREE.MeshStandardMaterial({ color, roughness, metalness });
    m.name = name;
    return m;
  };
  const mats = {
    coat: material('midnight-teal-wool', 0x124b68, .69),
    coatLight: material('raised-teal-lapels', 0x1c6080, .64),
    coatShadow: material('deep-blue-coat-seams', 0x0c3045, .79),
    gold: material('warm-aged-brass-piping', 0xd9a246, .36, .65),
    goldBright: material('polished-brass-fasteners', 0xf0b951, .28, .72),
    vest: material('olive-brocade-waistcoat', 0x626138, .73),
    vestSeam: material('waistcoat-stitching', 0xaaa46a, .73),
    shirt: material('warm-ivory-shirt', 0xf3dfb0, .84),
    scarf: material('orange-silk-neckerchief', 0xc94b1c, .48),
    scarfLight: material('scarf-raised-folds', 0xe56620, .48),
    scarfDark: material('scarf-fold-shadow', 0x9f3315, .63),
    leather: material('warm-brown-belts', 0x633b22, .64),
    leatherDark: material('dark-leather-seams', 0x34291f, .69),
    trouser: material('tobacco-brown-trousers', 0x594334, .86),
    boot: material('soft-captains-boots', 0x2c2824, .52),
    bootFold: material('boot-cuff-leather', 0x4b392c, .56),
    sole: material('boot-welt-and-soles', 0x171d1d, .83),
    wood: material('polished-walnut-chair', 0x5b3020, .48),
    woodLight: material('carved-walnut-chair-edges', 0x85502d, .47),
    seat: material('chair-oxblood-cushion', 0x773f2c, .76),
  };
  const sphere = new THREE.SphereGeometry(1, 32, 24);
  const axisY = new THREE.Vector3(0, 1, 0);
  const v = (p) => new THREE.Vector3(...p);

  function mesh(geometry, mat, name, parent = costume) {
    const m = new THREE.Mesh(geometry, typeof mat === 'string' ? mats[mat] : mat);
    m.name = name;
    m.castShadow = m.receiveShadow = true;
    parent.add(m);
    return m;
  }

  function ellipsoid(name, position, scale, mat, parent = costume) {
    const m = mesh(sphere, mat, name, parent);
    m.position.set(...position);
    m.scale.set(...scale);
    return m;
  }

  function rod(name, a, b, radiusA, radiusB, mat, parent = costume) {
    const from = v(a), to = v(b), delta = to.clone().sub(from);
    const m = mesh(new THREE.CylinderGeometry(radiusB, radiusA, delta.length(), 24), mat, name, parent);
    m.position.copy(from).addScaledVector(delta, .5);
    m.quaternion.setFromUnitVectors(axisY, delta.normalize());
    return m;
  }

  // Variable-radius curves avoid straight primitive limbs and square elbows.
  function sweep(name, points, radii, mat, parent = costume, segments = 44, sides = 16) {
    const curve = new THREE.CatmullRomCurve3(points.map(v));
    const frames = curve.computeFrenetFrames(segments, false);
    const positions = [], indices = [];
    for (let i = 0; i <= segments; i++) {
      const t = i / segments, center = curve.getPointAt(t);
      const ri = t * (radii.length - 1), r0 = Math.floor(ri), blend = ri - r0;
      const radius = radii[r0] * (1 - blend) + radii[Math.min(r0 + 1, radii.length - 1)] * blend;
      for (let j = 0; j < sides; j++) {
        const angle = j / sides * Math.PI * 2;
        const p = center.clone().addScaledVector(frames.normals[i], Math.cos(angle) * radius)
          .addScaledVector(frames.binormals[i], Math.sin(angle) * radius);
        positions.push(p.x, p.y, p.z);
        if (i < segments) {
          const a = i * sides + j, b = i * sides + (j + 1) % sides;
          indices.push(a, b, a + sides, b, b + sides, a + sides);
        }
      }
    }
    const start = positions.length / 3, first = curve.getPointAt(0), last = curve.getPointAt(1);
    positions.push(first.x, first.y, first.z, last.x, last.y, last.z);
    for (let j = 0; j < sides; j++) {
      indices.push(start, (j + 1) % sides, j);
      indices.push(start + 1, segments * sides + j, segments * sides + (j + 1) % sides);
    }
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
    geo.setIndex(indices);
    geo.computeVertexNormals();
    const m = mesh(geo, mat, name, parent);
    m.userData.curvePoints = points;
    return m;
  }

  function pipe(name, points, radius, mat = 'gold', parent = costume) {
    const c = new THREE.CatmullRomCurve3(points.map(v));
    return mesh(new THREE.TubeGeometry(c, Math.max(24, points.length * 7), radius, 8, false), mat, name, parent);
  }

  function cuffRing(name, center, tangent, majorRadius, tubeRadius, mat, parent = costume) {
    const m = mesh(new THREE.TorusGeometry(majorRadius, tubeRadius, 10, 40), mat, name, parent);
    m.position.set(...center);
    m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 0, 1), v(tangent).normalize());
    return m;
  }

  function roundedShape(points) {
    const shape = new THREE.Shape();
    const last = points[points.length - 1], first = points[0];
    shape.moveTo((last[0] + first[0]) / 2, (last[1] + first[1]) / 2);
    for (let i = 0; i < points.length; i++) {
      const current = points[i], next = points[(i + 1) % points.length];
      shape.quadraticCurveTo(current[0], current[1], (current[0] + next[0]) / 2, (current[1] + next[1]) / 2);
    }
    shape.closePath();
    return shape;
  }

  function frontZ(x, y) {
    return .81 * Math.sqrt(Math.max(.08, 1 - (x / 1.47) ** 2 - ((y - .35) / 1.85) ** 2));
  }

  // Tailored front pieces follow the curved chest instead of floating cards.
  function clothPanel(name, points, mat, lift = .04, depth = .065) {
    const geometry = new THREE.ExtrudeGeometry(roundedShape(points), {
      depth, bevelEnabled: true, bevelSegments: 3, steps: 1,
      bevelSize: .035, bevelThickness: .025, curveSegments: 8,
    });
    const p = geometry.attributes.position;
    for (let i = 0; i < p.count; i++) p.setZ(i, p.getZ(i) + frontZ(p.getX(i), p.getY(i)) + lift);
    geometry.computeVertexNormals();
    return mesh(geometry, mat, name);
  }

  function frontPipe(name, points, radius = .033, mat = 'gold', lift = .14) {
    return pipe(name, points.map(([x, y]) => [x, y, frontZ(x, y) + lift]), radius, mat);
  }

  // The coat has full thickness and a shaped back even below the tabletop.
  ellipsoid('rounded-tailored-coat-body', [0, .32, -.04], [1.36, 1.67, .83], 'coat');
  ellipsoid('left-hip-coattail', [-.72, -1.27, -.32], [.68, 1.12, .36], 'coat');
  ellipsoid('right-hip-coattail', [.72, -1.27, -.32], [.68, 1.12, .36], 'coat');
  pipe('back-center-seam', [[0, 1.62, -.61], [0, 1.0, -.82], [0, .1, -.88], [0, -.82, -.72], [0, -1.65, -.54]], .018, 'coatShadow');
  for (const sign of [-1, 1]) {
    pipe(`back-princess-seam-${sign}`, [[sign * .66, 1.45, -.64], [sign * .85, .65, -.72], [sign * .8, -.25, -.77], [sign * .98, -1.5, -.59]], .018, 'coatShadow');
    pipe(`coattail-gold-edge-${sign}`, [[sign * .36, -1.25, -.58], [sign * .38, -1.98, -.5], [sign * .72, -2.32, -.32], [sign * 1.14, -1.92, -.27]], .026, 'gold');
    ellipsoid(`rear-waist-button-${sign}`, [sign * .31, -.45, -.86], [.085, .085, .045], 'goldBright');
  }

  clothPanel('olive-waistcoat-front', [[-.76, -1.02], [-.87, .38], [-.59, 1.51], [0, 1.72], [.59, 1.51], [.87, .38], [.76, -1.02], [0, -1.18]], 'vest', .015);
  frontPipe('waistcoat-center-stitch', [[0, 1.25], [0, .65], [0, -.1], [0, -.95]], .014, 'vestSeam', .115);
  for (const sign of [-1, 1]) {
    clothPanel(`ivory-shirt-collar-${sign}`, [[0, 1.72], [sign * .55, 1.77], [sign * .55, 1.29], [sign * .19, .93]], 'shirt', .12);
    const lapel = [[sign * .55, 1.94], [sign * 1.43, 1.3], [sign * 1.09, .97], [sign * 1.43, .5], [sign * .86, .72], [sign * .7, -.98], [sign * .48, -.98], [sign * .56, .7], [sign * .23, 1.42]];
    clothPanel(`sculpted-open-coat-lapel-${sign}`, lapel, 'coatLight', .15, .08);
    frontPipe(`lapel-gold-outline-${sign}`, [lapel[0], lapel[1], lapel[2], lapel[3], lapel[4], lapel[5]], .035, 'gold', .24);
    for (const y of [-.82, -.22, .38]) {
      const x = sign * 1.0, z = frontZ(x, y) + .18;
      ellipsoid(`coat-button-backing-${sign}-${y}`, [x, y, z], [.145, .145, .065], 'coatShadow');
      ellipsoid(`large-brass-coat-button-${sign}-${y}`, [x, y, z + .045], [.112, .112, .065], 'gold');
      ellipsoid(`coat-button-center-${sign}-${y}`, [x, y, z + .1], [.067, .067, .025], 'goldBright');
    }
    frontPipe(`waistcoat-pocket-${sign}`, [[sign * .2, -.13], [sign * .43, -.12], [sign * .63, -.05]], .018, 'vestSeam', .13);
  }

  // Rounded bent sleeves. The cuffs are perpendicular to the forearm.
  for (const sign of [-1, 1]) {
    const s = (x, y, z) => [sign * x, y, z];
    sweep(`sculpted-bent-coat-sleeve-${sign}`, [s(1.1, 1.43, -.09), s(1.6, 1.16, .01), s(2.05, .55, .35), s(1.92, .46, .86), s(1.5, .42, 1.4)], [.61, .6, .57, .47, .37], 'coat');
    ellipsoid(`rounded-coat-shoulder-${sign}`, s(1.21, 1.4, -.04), [.64, .67, .61], 'coat');
    pipe(`sleeve-outer-seam-${sign}`, [s(1.65, 1.56, -.12), s(2.27, .92, .18), s(2.39, .42, .62), s(1.95, .36, 1.33)], .018, 'coatShadow');
    for (let f = 0; f < 3; f++) {
      pipe(`soft-elbow-fold-${sign}-${f}`, [s(2.32, .75 - f * .11, .32 + f * .1), s(2.37, .64 - f * .1, .57 + f * .09), s(2.19, .54 - f * .09, .76 + f * .08)], .019, 'coatLight');
    }
    const cuffStart = s(1.69, .45, 1.2), cuffEnd = s(1.46, .40, 1.49);
    rod(`deep-folded-cuff-${sign}`, cuffStart, cuffEnd, .38, .37, 'coatLight');
    const tangent = [sign * -.58, -.13, .78];
    cuffRing(`cuff-rear-gold-rim-${sign}`, cuffStart, tangent, .37, .032, 'gold');
    cuffRing(`cuff-front-gold-rim-${sign}`, cuffEnd, tangent, .36, .035, 'gold');
    // Buttons face upward so they remain visible in the normal board view.
    for (const f of [-1, 1]) {
      ellipsoid(`cuff-brass-button-${sign}-${f}`, s(1.72 + f * .12, .79, 1.22 + f * .08), [.09, .052, .09], 'goldBright');
    }
  }

  // A complete neckerchief, with a genuine knot and overlapping cloth tails.
  const scarfLoop = mesh(new THREE.TorusGeometry(.64, .17, 14, 48), 'scarf', 'orange-neck-scarf-loop');
  scarfLoop.rotation.x = Math.PI / 2;
  scarfLoop.position.set(0, 1.93, .05);
  scarfLoop.scale.set(1.12, .85, 1);
  sweep('scarf-front-rolled-fold', [[-.62, 1.94, .48], [-.4, 1.8, .8], [.05, 1.78, .95], [.48, 1.94, .84]], [.16, .2, .2, .16], 'scarf');
  pipe('scarf-silk-highlight', [[-.59, 1.99, .58], [-.26, 1.89, .89], [.13, 1.87, 1.03], [.43, 1.97, .93]], .026, 'scarfLight');
  const knot = ellipsoid('asymmetric-scarf-knot', [.48, 1.87, .91], [.25, .27, .21], 'scarfLight');
  knot.rotation.z = -.3;
  for (const x of [.38, .49, .6]) pipe(`knot-gathered-fold-${x}`, [[x, 2.04, 1], [x + .045, 1.88, 1.11], [x + .02, 1.68, 1.01]], .022, 'scarfDark');
  sweep('scarf-long-curled-tail', [[.55, 1.77, .94], [.78, 1.45, 1.06], [.76, 1.1, 1.02], [.99, .92, .98]], [.16, .23, .2, .025], 'scarf');
  sweep('scarf-short-folded-tail', [[.53, 1.78, .96], [.35, 1.51, 1.12], [.42, 1.25, 1.15], [.6, 1.2, 1.09]], [.13, .19, .16, .018], 'scarfLight');
  pipe('long-tail-raised-fold', [[.62, 1.67, 1.12], [.84, 1.38, 1.23], [.84, 1.13, 1.16], [.98, .98, 1.02]], .019, 'scarfLight');

  // A buckled diagonal baldric lies above the waistcoat but below the scarf.
  clothPanel('broad-diagonal-leather-baldric', [[-.96, 1.35], [-.65, 1.54], [1.02, -.79], [.73, -.98]], 'leather', .33, .055);
  frontPipe('baldric-left-stitched-edge', [[-.93, 1.32], [-.43, .64], [.12, -.1], [.74, -.92]], .012, 'gold', .405);
  frontPipe('baldric-right-stitched-edge', [[-.67, 1.48], [-.18, .79], [.37, .05], [.99, -.76]], .012, 'gold', .405);
  const buckle = new THREE.Group();
  buckle.name = 'raised-baldric-square-brass-buckle';
  buckle.position.set(.28, .05, frontZ(.28, .05) + .47);
  buckle.rotation.z = -.62;
  costume.add(buckle);
  const buckleOutline = [[-.25, -.28, 0], [.25, -.28, 0], [.25, .28, 0], [-.25, .28, 0], [-.25, -.28, 0]];
  pipe('rounded-square-buckle-frame', buckleOutline, .045, 'goldBright', buckle);
  rod('buckle-central-tongue', [-.19, .04, .025], [.15, .04, .025], .023, .023, 'gold', buckle);
  for (let i = 0; i < 4; i++) {
    const x = -.56 + i * .31, y = .96 - i * .43;
    ellipsoid(`baldric-punched-hole-${i}`, [x, y, frontZ(x, y) + .405], [.032, .04, .018], 'leatherDark');
  }
  const belt = mesh(new THREE.TorusGeometry(1, .115, 12, 64), 'leather', 'complete-waist-belt');
  belt.rotation.x = Math.PI / 2;
  belt.scale.set(1.23, .72, 1);
  belt.position.set(0, -.68, -.03);

  // Seated thighs and folded trousers are visible from every side of the table.
  for (const sign of [-1, 1]) {
    const s = (x, y, z) => [sign * x, y, z];
    sweep(`seated-trouser-thigh-${sign}`, [s(.64, -1.28, -.07), s(.77, -1.39, .54), s(.82, -1.93, 1.06)], [.57, .53, .43], 'trouser');
    sweep(`hanging-trouser-shin-${sign}`, [s(.82, -1.9, 1.06), s(.8, -2.47, .94), s(.8, -3.04, .91)], [.43, .36, .32], 'trouser');
    for (let i = 0; i < 2; i++) pipe(`trouser-knee-fold-${sign}-${i}`, [s(.52, -1.96 - i * .15, 1.24), s(.81, -1.99 - i * .15, 1.47), s(1.11, -1.96 - i * .15, 1.23)], .024, 'leatherDark');
    sweep(`soft-tall-boot-shaft-${sign}`, [s(.8, -2.72, .9), s(.8, -3.16, .86), s(.8, -3.52, .96)], [.39, .34, .37], 'boot');
    ellipsoid(`rounded-boot-foot-${sign}`, s(.8, -3.64, 1.24), [.42, .27, .78], 'boot');
    ellipsoid(`thick-curved-boot-sole-${sign}`, s(.8, -3.85, 1.24), [.44, .115, .79], 'sole');
    cuffRing(`soft-boot-top-fold-${sign}`, s(.8, -2.76, .9), [0, 1, 0], .39, .085, 'bootFold');
    pipe(`boot-outer-seam-${sign}`, [s(1.14, -2.83, .92), s(1.11, -3.25, .93), s(1.14, -3.6, 1.14)], .017, 'leather');
    pipe(`boot-toe-welt-${sign}`, [s(.41, -3.79, 1.47), s(.53, -3.79, 1.86), s(.8, -3.79, 2), s(1.07, -3.79, 1.86), s(1.19, -3.79, 1.47)], .02, 'bootFold');
  }

  // Solid carved chair: cushioned seat, curved back, four turned legs, arms.
  ellipsoid('rounded-walnut-seat-frame', [0, -1.76, -.3], [1.77, .23, 1.25], 'wood', chair);
  ellipsoid('plump-oxblood-seat-cushion', [0, -1.57, -.25], [1.58, .2, 1.1], 'seat', chair);
  for (const sign of [-1, 1]) {
    for (const front of [-1, 1]) {
      const x = sign * 1.43, z = -.3 + front * .95;
      const bottom = [sign * 1.62, -3.95, z + front * .16];
      sweep(`turned-chair-leg-${sign}-${front}`, [[x, -1.8, z], [x, -2.3, z], [sign * 1.55, -3.16, z + front * .08], bottom], [.13, .1, .12, .13], 'wood', chair, 28, 14);
      ellipsoid(`chair-foot-${sign}-${front}`, bottom, [.18, .075, .18], 'woodLight', chair);
      cuffRing(`chair-leg-collar-${sign}-${front}`, [x, -2.12, z], [0, 1, 0], .125, .023, 'woodLight', chair);
    }
    sweep(`chair-back-upright-${sign}`, [[sign * 1.42, -1.77, -1.22], [sign * 1.52, -.4, -1.4], [sign * 1.55, 1.24, -1.49], [sign * 1.4, 2.02, -1.44]], [.14, .14, .145, .13], 'wood', chair);
    ellipsoid(`chair-back-finial-${sign}`, [sign * 1.4, 2.12, -1.44], [.22, .25, .22], 'woodLight', chair);
    cuffRing(`chair-finial-brass-collar-${sign}`, [sign * 1.4, 1.94, -1.44], [0, 1, 0], .15, .026, 'gold', chair);
    sweep(`chair-armrest-${sign}`, [[sign * 1.5, -.1, -1.23], [sign * 1.85, -.22, -.7], [sign * 1.94, -.46, .35], [sign * 1.78, -.55, .7]], [.14, .14, .14, .13], 'woodLight', chair);
    sweep(`chair-front-arm-support-${sign}`, [[sign * 1.48, -1.74, .55], [sign * 1.73, -1.15, .58], [sign * 1.79, -.56, .62]], [.105, .12, .095], 'wood', chair);
    rod(`chair-side-stretcher-${sign}`, [sign * 1.52, -2.83, -1.3], [sign * 1.52, -2.83, .72], .065, .065, 'wood', chair);
  }
  const chairBack = ellipsoid('curved-solid-chair-back', [0, .08, -1.51], [1.49, 1.82, .19], 'wood', chair);
  chairBack.rotation.x = -.035;
  ellipsoid('chair-back-raised-center-panel', [0, .22, -1.3], [1.23, 1.5, .09], 'woodLight', chair);
  // A rear panel and three relief slats make the back as finished as the front.
  ellipsoid('chair-back-rear-carved-panel', [0, .22, -1.69], [1.23, 1.5, .075], 'woodLight', chair);
  for (const x of [-.75, 0, .75]) {
    pipe(`chair-rear-carved-flute-${x}`, [[x * .75, 1.43, -1.72], [x, .65, -1.77], [x, -.25, -1.77], [x * .88, -.95, -1.71]], .025, 'wood', chair);
  }
  pipe('chair-rounded-top-crest', [[-1.4, 1.97, -1.44], [-.92, 2.27, -1.49], [0, 2.4, -1.52], [.92, 2.27, -1.49], [1.4, 1.97, -1.44]], .15, 'woodLight', chair);
  pipe('chair-brass-crest-inlay', [[-1.18, 2.08, -1.31], [-.65, 2.26, -1.35], [0, 2.3, -1.36], [.65, 2.26, -1.35], [1.18, 2.08, -1.31]], .022, 'gold', chair);
  rod('chair-front-lower-stretcher', [-1.55, -2.85, .73], [1.55, -2.85, .73], .07, .07, 'wood', chair);
  rod('chair-rear-lower-stretcher', [-1.55, -2.85, -1.34], [1.55, -2.85, -1.34], .07, .07, 'wood', chair);

  // Kept as ordinary data for inspection; it does not affect GLTF serialization.
  root.userData.modelRole = 'volumetric-seated-pirate-frog-outfit';
  root.userData.frontAxis = '+Z';
  root.userData.tabletopY = 0;
  root.userData.floorY = -4;
  root.userData.handCenters = [[-1.5, .12, 1.75], [1.5, .12, 1.75]];
  return root;
}
