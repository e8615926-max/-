// Battlefield: terrain, structures, decorations, weather
import * as THREE from '../lib/three.module.min.js';
import { G, rand, pick, clamp, rayBox, ALLY, ENEMY } from './state.js';
import { MAT, makeFlag } from './models.js';
import * as SFX from './audio.js';

export const MAP = { minX: -88, maxX: 88, minZ: -178, maxZ: 178, W: 260, D: 470 };
export const BASES = [
  { team: ALLY, x: 0, z: 152, med: { x: -14, z: 150 }, shop: { x: 14, z: 150 }, spawn: { x: 0, z: 158 }, dir: -1 },
  { team: ENEMY, x: 0, z: -152, med: { x: 14, z: -150 }, shop: { x: -14, z: -150 }, spawn: { x: 0, z: -158 }, dir: 1 },
];
export const FLAG_POS = [
  { name: 'A', x: 22, z: 70 }, { name: 'B', x: -8, z: 0 }, { name: 'C', x: 20, z: -70 },
];
const CRATERS = [];
for (let i = 0; i < 46; i++) {
  const x = rand(-80, 80), z = rand(-120, 120);
  CRATERS.push({ x, z, r: rand(2, i < 8 ? 7 : 4.5), d: rand(0.6, 1.8) });
}

// -------- height grid --------
const GW = MAP.W + 1, GD = MAP.D + 1, OX = -MAP.W / 2, OZ = -MAP.D / 2;
const HGRID = new Float32Array(GW * GD);
function smooth(e0, e1, x) { const t = clamp((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t); }
function rawHeight(x, z) {
  let h = Math.sin(x * 0.045) * 1.5 + Math.cos(z * 0.033 + 1) * 1.7 + Math.sin((x + z) * 0.08) * 0.6 + Math.sin(x * 0.17 - z * 0.13) * 0.3 + Math.cos(x * 0.31 + z * 0.27) * 0.12;
  // ridge in the middle of the map + hills on the flanks
  h += Math.exp(-((z - 30) ** 2) / 300) * 1.8 * (0.5 + 0.5 * Math.sin(x * 0.06));
  h += Math.exp(-((z + 30) ** 2) / 300) * 1.8 * (0.5 + 0.5 * Math.cos(x * 0.06));
  for (const c of CRATERS) {
    const d = Math.hypot(x - c.x, z - c.z);
    if (d < c.r) h -= c.d * (1 - (d / c.r) ** 2);
    else if (d < c.r * 1.5) h += c.d * 0.25 * Math.sin((d - c.r) / (c.r * 0.5) * Math.PI);
  }
  // flatten bases & flag zones
  for (const b of BASES) { const d = Math.hypot(x - b.x, z - b.z); h *= smooth(26, 40, d); }
  for (const f of FLAG_POS) { const d = Math.hypot(x - f.x, z - f.z); h = h * smooth(6, 14, d) + 0.3 * (1 - smooth(6, 14, d)); }
  // boundary mountains
  const ex = Math.max(0, Math.abs(x) - MAP.maxX), ez = Math.max(0, Math.abs(z) - MAP.maxZ);
  const e = Math.hypot(ex, ez);
  h += e * e * 0.006 + e * 0.25;
  return h;
}
for (let j = 0; j < GD; j++) for (let i = 0; i < GW; i++) HGRID[j * GW + i] = rawHeight(OX + i, OZ + j);

export function heightAt(x, z) {
  let fx = x - OX, fz = z - OZ;
  if (fx < 0) fx = 0; if (fz < 0) fz = 0; if (fx > GW - 1.001) fx = GW - 1.001; if (fz > GD - 1.001) fz = GD - 1.001;
  const i = fx | 0, j = fz | 0, tx = fx - i, tz = fz - j;
  const a = HGRID[j * GW + i], b = HGRID[j * GW + i + 1], c = HGRID[(j + 1) * GW + i], d = HGRID[(j + 1) * GW + i + 1];
  return (a * (1 - tx) + b * tx) * (1 - tz) + (c * (1 - tx) + d * tx) * tz;
}
export function normalAt(x, z, out) {
  const e = 0.8; const hx = heightAt(x + e, z) - heightAt(x - e, z), hz = heightAt(x, z + e) - heightAt(x, z - e);
  return out.set(-hx, 2 * e, -hz).normalize();
}

// -------- colliders --------
export const colliders = [];
function addCollider(minX, minY, minZ, maxX, maxY, maxZ, mat = 'concrete', extra = {}) {
  const c = { minX, minY, minZ, maxX, maxY, maxZ, mat, ...extra };
  colliders.push(c); return c;
}

// circle (xz) push-out vs colliders; height filter so you can stand behind low cover
export function pushOut(pos, r, feetY, height = 1.7) {
  let hit = false;
  for (let k = 0; k < colliders.length; k++) {
    const c = colliders[k];
    if (c.dead) continue;
    if (feetY + height < c.minY || feetY + 0.45 > c.maxY) continue;
    const cx = clamp(pos.x, c.minX, c.maxX), cz = clamp(pos.z, c.minZ, c.maxZ);
    const dx = pos.x - cx, dz = pos.z - cz; const d2 = dx * dx + dz * dz;
    if (d2 < r * r) {
      hit = true;
      if (d2 > 1e-6) { const d = Math.sqrt(d2); pos.x = cx + dx / d * r; pos.z = cz + dz / d * r; }
      else { // inside: push along smallest axis
        const l = pos.x - c.minX, rr = c.maxX - pos.x, b = pos.z - c.minZ, f = c.maxZ - pos.z; const m = Math.min(l, rr, b, f);
        if (m === l) pos.x = c.minX - r; else if (m === rr) pos.x = c.maxX + r; else if (m === b) pos.z = c.minZ - r; else pos.z = c.maxZ + r;
      }
    }
  }
  pos.x = clamp(pos.x, MAP.minX, MAP.maxX); pos.z = clamp(pos.z, MAP.minZ, MAP.maxZ);
  return hit;
}
// highest collider top under a point (for standing on low objects)
export function groundAt(x, z, y) {
  let g = heightAt(x, z);
  for (const c of colliders) {
    if (c.dead || !c.walkable) continue;
    if (x > c.minX && x < c.maxX && z > c.minZ && z < c.maxZ && c.maxY <= y + 0.6 && c.maxY > g) g = c.maxY;
  }
  return g;
}

// Ray against static world: returns {t, n:{x,y,z}, mat} or null
const _n = new THREE.Vector3();
export function rayWorld(o, d, maxT, terrain = true, step = 0.9) {
  let best = maxT, bn = null, bm = null;
  const ex = o.x + d.x * maxT, ey = o.y + d.y * maxT, ez = o.z + d.z * maxT;
  const sx0 = Math.min(o.x, ex), sx1 = Math.max(o.x, ex), sy0 = Math.min(o.y, ey), sy1 = Math.max(o.y, ey), sz0 = Math.min(o.z, ez), sz1 = Math.max(o.z, ez);
  for (let k = 0; k < colliders.length; k++) {
    const c = colliders[k]; if (c.dead) continue;
    if (c.maxX < sx0 || c.minX > sx1 || c.maxZ < sz0 || c.minZ > sz1 || c.maxY < sy0 || c.minY > sy1) continue;
    const h = rayBox(o, d, c, best);
    if (h && h.t < best) { best = h.t; bn = { x: h.nx, y: h.ny, z: h.nz }; bm = c.mat; }
  }
  if (terrain) {
    let prevT = 0, prevAbove = o.y - heightAt(o.x, o.z);
    if (prevAbove < 0) return { t: 0, n: { x: 0, y: 1, z: 0 }, mat: 'dirt' };
    const lim = Math.min(best, maxT);
    for (let t = step; t <= lim + step; t += step) {
      const tt = Math.min(t, lim);
      const x = o.x + d.x * tt, y = o.y + d.y * tt, z = o.z + d.z * tt;
      const above = y - heightAt(x, z);
      if (above < 0) {
        let a = prevT, b = tt;
        for (let i = 0; i < 6; i++) { const m = (a + b) / 2; const ym = o.y + d.y * m - heightAt(o.x + d.x * m, o.z + d.z * m); if (ym < 0) b = m; else a = m; }
        if (b < best) { const px = o.x + d.x * b, pz = o.z + d.z * b; normalAt(px, pz, _n); return { t: b, n: { x: _n.x, y: _n.y, z: _n.z }, mat: 'dirt' }; }
        break;
      }
      prevT = tt; prevAbove = above;
      if (tt >= lim) break;
    }
  }
  return bn ? { t: best, n: bn, mat: bm } : null;
}
const _d = new THREE.Vector3();
export function losClear(a, b) {
  _d.subVectors(b, a); const len = _d.length(); if (len < 0.01) return true; _d.divideScalar(len);
  const h = rayWorld(a, _d, len - 0.3, true, 3.5);
  return !h;
}

// -------- textures --------
function noiseTex(size, base, vari, scale = 1, lines = false) {
  const c = document.createElement('canvas'); c.width = c.height = size; const x = c.getContext('2d');
  const img = x.createImageData(size, size);
  for (let i = 0; i < size * size; i++) {
    const n = (Math.random() - 0.5) * vari;
    const px = i % size, py = (i / size) | 0;
    const l = lines ? Math.sin(px * 0.7 + Math.sin(py * 0.05) * 4) * vari * 0.3 : 0;
    img.data[i * 4] = clamp(base[0] + n + l, 0, 255); img.data[i * 4 + 1] = clamp(base[1] + n + l, 0, 255); img.data[i * 4 + 2] = clamp(base[2] + n + l, 0, 255); img.data[i * 4 + 3] = 255;
  }
  x.putImageData(img, 0, 0);
  // blotches
  for (let i = 0; i < 40 * scale; i++) {
    x.fillStyle = `rgba(${Math.random() < 0.5 ? '20,18,12' : '90,85,60'},${rand(0.04, 0.12)})`;
    x.beginPath(); x.arc(rand(0, size), rand(0, size), rand(3, size / 8), 0, 7); x.fill();
  }
  const t = new THREE.CanvasTexture(c); t.wrapS = t.wrapT = THREE.RepeatWrapping; t.colorSpace = THREE.SRGBColorSpace;
  return t;
}
function signTex(text, bg = '#1d2a1a', fg = '#e8e4d0', red = false) {
  const c = document.createElement('canvas'); c.width = 256; c.height = 96; const x = c.getContext('2d');
  x.fillStyle = bg; x.fillRect(0, 0, 256, 96); x.strokeStyle = fg; x.lineWidth = 6; x.strokeRect(6, 6, 244, 84);
  x.fillStyle = red ? '#d01818' : fg; x.font = 'bold 40px Arial'; x.textAlign = 'center'; x.textBaseline = 'middle'; x.fillText(text, 128, 50);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}

// -------- world build --------
export const world = { fires: [], puddles: [], flags: [], lightning: 0, nextLightning: 8, rain: null, sun: null, hemi: null, sky: null, smokeColumns: [], lamps: [] };

export function buildWorld(scene, quality) {
  const hi = quality === 'high';
  scene.fog = new THREE.FogExp2(0x58616a, 0.0115);
  scene.background = new THREE.Color(0x58616a);
  const hemi = new THREE.HemisphereLight(0x9aa8b6, 0x3b3426, 1.25); scene.add(hemi); world.hemi = hemi;
  const sun = new THREE.DirectionalLight(0xc2cdd8, 0.95); sun.position.set(-40, 80, 30); scene.add(sun); scene.add(sun.target); world.sun = sun;
  if (hi) {
    sun.castShadow = true; sun.shadow.mapSize.set(1024, 1024);
    const s = sun.shadow.camera; s.left = -45; s.right = 45; s.top = 45; s.bottom = -45; s.near = 10; s.far = 200; sun.shadow.bias = -0.0015;
  }
  // sky dome
  const skyMat = new THREE.ShaderMaterial({
    side: THREE.BackSide, depthWrite: false, fog: false,
    uniforms: { flash: { value: 0 }, time: { value: 0 } },
    vertexShader: 'varying vec3 vp; void main(){ vp = position; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.0);} ',
    fragmentShader: `varying vec3 vp; uniform float flash; uniform float time;
      float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
      float n(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
      float fbm(vec2 p){float v=0.,a=.5;for(int i=0;i<5;i++){v+=a*n(p);p*=2.03;a*=.5;}return v;}
      void main(){ vec3 d=normalize(vp); float y=d.y;
        vec3 top=vec3(.17,.19,.22), hor=vec3(.36,.39,.43);
        vec3 col=mix(hor,top,smoothstep(0.,.6,y));
        vec2 uv=d.xz/(y+.25)*1.6+vec2(time*.012,time*.004);
        float c=fbm(uv*1.7); col=mix(col,col*.62,smoothstep(.25,.95,c)*smoothstep(-.05,.3,y));
        col+=vec3(.7,.75,.85)*flash*(.6+c);
        col=mix(vec3(.345,.38,.415),col,smoothstep(-.02,.12,y));
        gl_FragColor=vec4(col,1.);} `,
  });
  const sky = new THREE.Mesh(new THREE.SphereGeometry(380, 24, 12), skyMat); scene.add(sky); world.sky = sky;

  // terrain
  const tg = new THREE.PlaneGeometry(MAP.W, MAP.D, MAP.W / 2, MAP.D / 2); tg.rotateX(-Math.PI / 2);
  const pos = tg.attributes.position; const cols = new Float32Array(pos.count * 3);
  const cMud = new THREE.Color(0x4a3d2c), cGrass = new THREE.Color(0x3f4a2a), cDark = new THREE.Color(0x2c2620), cWet = new THREE.Color(0x3a3229), tmp = new THREE.Color();
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), z = pos.getZ(i); const y = heightAt(x, z); pos.setY(i, y);
    const n = Math.sin(x * 0.11) * Math.cos(z * 0.09) + Math.sin(x * 0.03 + z * 0.05) * 0.8;
    tmp.copy(cMud).lerp(cGrass, clamp(n * 0.5 + 0.5, 0, 1));
    let crater = 0; for (const c of CRATERS) { const d = Math.hypot(x - c.x, z - c.z); if (d < c.r * 1.2) crater = Math.max(crater, 1 - d / (c.r * 1.2)); }
    tmp.lerp(cDark, crater * 0.9);
    // roads/tracks along the map
    const road = Math.max(0, 1 - Math.abs(x - Math.sin(z * 0.03) * 12) / 4);
    tmp.lerp(cWet, road * 0.7);
    for (const b of BASES) { const d = Math.hypot(x - b.x, z - b.z); if (d < 30) tmp.lerp(new THREE.Color(0x4d4535), (1 - d / 30) * 0.6); }
    cols[i * 3] = tmp.r; cols[i * 3 + 1] = tmp.g; cols[i * 3 + 2] = tmp.b;
  }
  tg.setAttribute('color', new THREE.BufferAttribute(cols, 3)); tg.computeVertexNormals();
  const gtex = noiseTex(256, [150, 140, 120], 60, 2); gtex.repeat.set(MAP.W / 6, MAP.D / 6);
  const terrain = new THREE.Mesh(tg, new THREE.MeshLambertMaterial({ map: gtex, vertexColors: true }));
  terrain.receiveShadow = true; scene.add(terrain);

  const concrete = new THREE.MeshLambertMaterial({ map: noiseTex(128, [128, 124, 116], 40, 1), color: 0x9a978f });
  const brick = new THREE.MeshLambertMaterial({ map: noiseTex(128, [130, 82, 62], 50, 1, true), color: 0xaa8f80 });
  const woodM = new THREE.MeshLambertMaterial({ map: noiseTex(64, [100, 70, 45], 40, 0.5, true) });
  const metalM = new THREE.MeshLambertMaterial({ color: 0x4a4d50 });
  const rust = new THREE.MeshLambertMaterial({ color: 0x5b3a26 });

  const box = (x, y, z, w, h, d, mat, cmat = 'concrete', col = true, walkable = false) => {
    const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat); m.position.set(x, y + h / 2, z); m.castShadow = hi; m.receiveShadow = hi; scene.add(m);
    if (col) addCollider(x - w / 2, y, z - d / 2, x + w / 2, y + h, z + d / 2, cmat, { walkable });
    return m;
  };

  // ---- sandbag walls (instanced) ----
  const sbGeo = new THREE.BoxGeometry(0.62, 0.3, 0.38);
  const sbPositions = [];
  const sandbags = (x, z, len, alongX, rows = 3) => {
    const y0 = heightAt(x, z) - 0.05;
    const n = Math.max(1, Math.round(len / 0.6));
    for (let r = 0; r < rows; r++) for (let i = 0; i < n; i++) {
      const off = -len / 2 + (i + 0.5 + (r % 2) * 0.5) * (len / n);
      if (off > len / 2) continue;
      sbPositions.push([alongX ? x + off : x, y0 + 0.15 + r * 0.28, alongX ? z : z + off, alongX ? 0 : Math.PI / 2, rand(-0.1, 0.1)]);
    }
    const h = rows * 0.28 + 0.1;
    if (alongX) addCollider(x - len / 2, y0, z - 0.25, x + len / 2, y0 + h, z + 0.25, 'sand', { walkable: true });
    else addCollider(x - 0.25, y0, z - len / 2, x + 0.25, y0 + h, z + len / 2, 'sand', { walkable: true });
  };

  // ---- ruined house ----
  const house = (x, z, w, d, h, mat) => {
    const y0 = heightAt(x, z) - 0.3; const t = 0.35;
    box(x, y0, z, w + 0.4, 0.35, d + 0.4, concrete, 'concrete', true, true); // floor slab
    const wall = (cx, cz, len, alongX, door) => {
      const segs = door ? [[-len / 2, -0.8], [0.8, len / 2]] : [[-len / 2, len / 2]];
      for (const [a, b] of segs) {
        const L = b - a; if (L < 0.3) continue; const mid = (a + b) / 2;
        // broken top: split into 2 parts of different heights
        const parts = L > 3 ? 2 : 1;
        for (let p = 0; p < parts; p++) {
          const pl = L / parts; const pm = a + pl * (p + 0.5); const hh = h * rand(0.45, 1);
          if (alongX) box(cx + pm, y0 + 0.3, cz, pl, hh, t, mat);
          else box(cx, y0 + 0.3, cz + pm, t, hh, pl, mat);
        }
        if (door && Math.random() < 0.6) { // lintel
          if (alongX) box(cx, y0 + 2.3, cz, 1.6, 0.4, t, mat, 'concrete', true); else box(cx, y0 + 2.3, cz, t, 0.4, 1.6, mat, 'concrete', true);
        }
        void mid;
      }
    };
    wall(x, z - d / 2, w, true, Math.random() < 0.7); wall(x, z + d / 2, w, true, Math.random() < 0.7);
    wall(x - w / 2, z, d, false, Math.random() < 0.6); wall(x + w / 2, z, d, false, Math.random() < 0.6);
    // rubble
    for (let i = 0; i < 8; i++) { const r = new THREE.Mesh(new THREE.DodecahedronGeometry(rand(0.2, 0.6), 0), mat); r.position.set(x + rand(-w, w) * 0.7, y0 + 0.4, z + rand(-d, d) * 0.7); r.rotation.set(rand(0, 3), rand(0, 3), 0); scene.add(r); }
    // collapsed roof slab
    if (Math.random() < 0.5) { const s = box(x + rand(-1, 1), y0 + 0.4, z + rand(-1, 1), w * 0.6, 0.25, d * 0.5, concrete, 'concrete', false); s.rotation.z = rand(0.2, 0.4); }
  };

  // ---- structures around flags ----
  const housePlan = [
    [30, 78, 7, 6, 3.4], [10, 60, 6, 6, 3], [36, 58, 5, 5, 3.2],
    [-20, 6, 8, 7, 4], [4, -10, 6, 5, 3], [-2, 14, 5, 6, 3],
    [32, -62, 7, 6, 3.4], [8, -80, 6, 6, 3], [30, -84, 5, 5, 3],
    [-55, 40, 8, 6, 3.5], [-50, -45, 7, 6, 3.5], [60, 15, 6, 6, 3], [62, -20, 6, 7, 3.2], [-60, 100, 7, 7, 3], [55, -105, 7, 7, 3],
  ];
  housePlan.forEach(([x, z, w, d, h], i) => house(x, z, w, d, h, i % 2 ? brick : concrete));

  // sandbag lines: trenches across the map
  for (const f of FLAG_POS) {
    sandbags(f.x - 9, f.z + 8, 6, true); sandbags(f.x + 9, f.z - 8, 6, true);
    sandbags(f.x + 11, f.z + 5, 5, false); sandbags(f.x - 11, f.z - 5, 5, false);
  }
  for (const zz of [110, 35, -35, -110]) for (let x = -70; x < 70; x += rand(12, 22)) sandbags(x, zz + rand(-3, 3), rand(3, 6), true, 2);

  // ---- bases ----
  const tentGeo = new THREE.CylinderGeometry(0.01, 4.2, 3.2, 4, 1, true); tentGeo.rotateY(Math.PI / 4);
  for (const b of BASES) {
    const ally = b.team === ALLY; const s = b.dir; // dir: toward enemy along z
    // perimeter sandbags with gaps
    for (let x = -34; x <= 34; x += 8) if (Math.abs(x) > 6) sandbags(b.x + x, b.z + s * 24, 6, true, 3);
    for (let zz = -18; zz <= 18; zz += 9) { sandbags(b.x - 38, b.z + zz, 7, false, 3); sandbags(b.x + 38, b.z + zz, 7, false, 3); }
    // medical tent
    const mt = new THREE.Mesh(tentGeo, new THREE.MeshLambertMaterial({ color: 0xd8d6cc, side: THREE.DoubleSide })); mt.position.set(b.med.x, 1.6, b.med.z); mt.scale.set(1.2, 1, 1); scene.add(mt);
    const sign1 = new THREE.Sprite(new THREE.SpriteMaterial({ map: signTex('✚ МЕДПУНКТ', '#e8e6dc', '#c81010', true) })); sign1.scale.set(4, 1.5, 1); sign1.position.set(b.med.x, 4.2, b.med.z); scene.add(sign1);
    // red cross on roof
    for (const r of [0, Math.PI / 2]) { const c = new THREE.Mesh(new THREE.BoxGeometry(2.4, 0.05, 0.6), MAT.red); c.position.set(b.med.x, 3.25, b.med.z); c.rotation.y = r; scene.add(c); }
    // cots
    for (let i = -1; i <= 1; i++) box(b.med.x + i * 1.6, 0, b.med.z + 2.5, 0.8, 0.45, 2, woodM, 'wood', false);
    // armory / shop tent
    const st = new THREE.Mesh(tentGeo, new THREE.MeshLambertMaterial({ color: ally ? 0x4b5a35 : 0x5a5d50, side: THREE.DoubleSide })); st.position.set(b.shop.x, 1.6, b.shop.z); st.scale.set(1.2, 1, 1); scene.add(st);
    const sign2 = new THREE.Sprite(new THREE.SpriteMaterial({ map: signTex('СКЛАД ⚒') })); sign2.scale.set(4, 1.5, 1); sign2.position.set(b.shop.x, 4.2, b.shop.z); scene.add(sign2);
    for (let i = 0; i < 6; i++) box(b.shop.x + rand(-3, 3), 0, b.shop.z + rand(2.5, 4.5), 1, rand(0.6, 1), 0.8, woodM, 'wood', false);
    // HQ bunker
    box(b.x, 0, b.z - s * 16, 10, 2.6, 6, concrete); // HQ bunker behind the spawn
    const sign3 = new THREE.Sprite(new THREE.SpriteMaterial({ map: signTex(ally ? 'ШТАБ' : 'ШТАБ ВРАГА', ally ? '#1d2a1a' : '#2a1a1a') })); sign3.scale.set(4, 1.5, 1); sign3.position.set(b.x, 4.2, b.z - s * 16); scene.add(sign3);
    // watch towers
    for (const sx of [-30, 30]) {
      const tx = b.x + sx, tz = b.z + s * 20;
      for (const [ox, oz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) box(tx + ox, 0, tz + oz, 0.2, 5, 0.2, woodM, 'wood', false);
      box(tx, 5, tz, 2.6, 0.2, 2.6, woodM, 'wood', false); box(tx, 5.2, tz, 2.6, 0.8, 0.1, woodM, 'wood', false);
      const lamp = new THREE.Mesh(new THREE.SphereGeometry(0.2, 8, 6), new THREE.MeshBasicMaterial({ color: 0xffe9b0 })); lamp.position.set(tx, 6.2, tz); scene.add(lamp);
    }
    // base flag
    const bf = makeFlag(); bf.position.set(b.x, 0, b.z); bf.userData.clothMat.color.set(ally ? 0x2f6ad0 : 0xc0281e); scene.add(bf); world.flags.push(bf);
    // drone pad sign
    const sign4 = new THREE.Sprite(new THREE.SpriteMaterial({ map: signTex('БПЛА', '#1a1d2a') })); sign4.scale.set(3, 1.1, 1); sign4.position.set(b.x + 24, 2.4, b.z); scene.add(sign4);
    const pad = new THREE.Mesh(new THREE.CircleGeometry(2.5, 20), new THREE.MeshLambertMaterial({ color: 0x333333 })); pad.rotation.x = -Math.PI / 2; pad.position.set(b.x + 24, heightAt(b.x + 24, b.z) + 0.05, b.z + 3); scene.add(pad);
    // fuel barrels & crates
    for (let i = 0; i < 8; i++) { const bx = b.x - 26 + rand(-3, 3), bz = b.z + rand(-6, 6); const m = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.3, 0.9, 10), i % 2 ? rust : metalM); m.position.set(bx, 0.45, bz); scene.add(m); addCollider(bx - 0.3, 0, bz - 0.3, bx + 0.3, 0.9, bz + 0.3, 'metal'); }
    // camo net over tank park
    const net = new THREE.Mesh(new THREE.PlaneGeometry(16, 10, 6, 4), new THREE.MeshLambertMaterial({ color: ally ? 0x3b4728 : 0x4b4a3a, side: THREE.DoubleSide, transparent: true, opacity: 0.85 }));
    net.rotation.x = -Math.PI / 2; net.position.set(b.x - 18, 3.4, b.z - s * 6); scene.add(net);
    for (const [ox, oz] of [[-8, -5], [8, -5], [-8, 5], [8, 5]]) box(b.x - 18 + ox, 0, b.z - s * 6 + oz, 0.15, 3.4, 0.15, woodM, 'wood', false);
  }

  // ---- instanced decorations ----
  const dummy = new THREE.Object3D();
  const inst = (geo, mat, list, shadow = false) => {
    const im = new THREE.InstancedMesh(geo, mat, list.length);
    list.forEach((p, i) => { dummy.position.set(p[0], p[1], p[2]); dummy.rotation.set(p[4] || 0, p[3] || 0, p[5] || 0); dummy.scale.setScalar(p[6] || 1); if (p[7]) dummy.scale.set(p[6] * (p[7] || 1), p[6], p[6]); dummy.updateMatrix(); im.setMatrixAt(i, dummy.matrix); });
    im.castShadow = shadow; im.receiveShadow = false; scene.add(im); return im;
  };
  inst(sbGeo, new THREE.MeshLambertMaterial({ color: 0x857654 }), sbPositions.map(p => [p[0], p[1], p[2], p[3] + p[4], 0, 0, 1]), hi);

  // trees (pine + dead)
  const trees = [], dead = [];
  const okSpot = (x, z) => {
    for (const b of BASES) if (Math.hypot(x - b.x, z - b.z) < 42) return false;
    for (const f of FLAG_POS) if (Math.hypot(x - f.x, z - f.z) < 16) return false;
    for (const [hx, hz, w, d] of housePlan) if (Math.abs(x - hx) < w && Math.abs(z - hz) < d) return false;
    return true;
  };
  for (let i = 0; i < (hi ? 320 : 200); i++) {
    let x, z;
    if (i < 140) { const side = Math.random() < 0.5 ? -1 : 1; x = side * rand(66, 120); z = rand(-230, 230); }
    else if (i < 180) { x = rand(-130, 130); z = (Math.random() < 0.5 ? -1 : 1) * rand(182, 230); }
    else { x = rand(-80, 80); z = rand(-150, 150); }
    if (!okSpot(x, z)) continue;
    const y = heightAt(x, z); const s = rand(0.8, 1.5);
    if (Math.random() < (Math.abs(x) < 60 ? 0.6 : 0.2)) dead.push([x, y, z, rand(0, 6), rand(-0.1, 0.1), rand(-0.1, 0.1), s]);
    else trees.push([x, y, z, rand(0, 6), 0, 0, s]);
    if (Math.abs(x) < 85 && Math.abs(z) < 175) addCollider(x - 0.25 * s, y, z - 0.25 * s, x + 0.25 * s, y + 6, z + 0.25 * s, 'wood');
  }
  const trunkGeo = new THREE.CylinderGeometry(0.12, 0.22, 3, 6); trunkGeo.translate(0, 1.5, 0);
  const trunkM = new THREE.MeshLambertMaterial({ color: 0x3a2c20 });
  inst(trunkGeo, trunkM, trees, hi);
  const coneGeo = new THREE.ConeGeometry(1.6, 4.2, 7); coneGeo.translate(0, 4.3, 0);
  const cone2 = new THREE.ConeGeometry(1.2, 3.2, 7); cone2.translate(0, 6.0, 0);
  const pineM = new THREE.MeshLambertMaterial({ color: 0x24301f });
  inst(coneGeo, pineM, trees, hi); inst(cone2, pineM, trees, hi);
  const deadGeo = new THREE.CylinderGeometry(0.06, 0.2, 5.5, 5); deadGeo.translate(0, 2.75, 0);
  const deadM = new THREE.MeshLambertMaterial({ color: 0x2a2520 });
  inst(deadGeo, deadM, dead, hi);
  const branchGeo = new THREE.CylinderGeometry(0.03, 0.07, 1.8, 4); branchGeo.translate(0, 0.9, 0); branchGeo.rotateZ(0.9); branchGeo.translate(0, 2.8, 0);
  inst(branchGeo, deadM, dead.map(p => [p[0], p[1], p[2], p[3], 0, 0, p[6]]));
  inst(branchGeo, deadM, dead.map(p => [p[0], p[1] + 0.8, p[2], p[3] + 2.4, 0, 0, p[6] * 0.8]));

  // rocks
  const rocks = []; for (let i = 0; i < 90; i++) { const x = rand(-85, 85), z = rand(-170, 170); if (!okSpot(x, z)) continue; rocks.push([x, heightAt(x, z) - 0.1, z, rand(0, 6), rand(0, 1), rand(0, 1), rand(0.3, 1.1)]); }
  inst(new THREE.DodecahedronGeometry(0.7, 0), new THREE.MeshLambertMaterial({ color: 0x5e5a54 }), rocks, hi);

  // grass tufts
  const grass = []; for (let i = 0; i < (hi ? 2600 : 1200); i++) { const x = rand(-88, 88), z = rand(-176, 176); grass.push([x, heightAt(x, z), z, rand(0, 6), 0, 0, rand(0.5, 1.2)]); }
  const gg = new THREE.PlaneGeometry(0.9, 0.6); gg.translate(0, 0.3, 0); const gg2 = gg.clone().rotateY(Math.PI / 2);
  const grassGeo = mergeGeos([gg, gg2]);
  const gc = document.createElement('canvas'); gc.width = 64; gc.height = 64; const gx = gc.getContext('2d');
  for (let i = 0; i < 26; i++) { gx.strokeStyle = `rgb(${50 + rand(0, 30)},${62 + rand(0, 30)},${30 + rand(0, 15)})`; gx.lineWidth = 2; gx.beginPath(); const bx = rand(4, 60); gx.moveTo(bx, 64); gx.quadraticCurveTo(bx + rand(-6, 6), 30, bx + rand(-12, 12), rand(4, 30)); gx.stroke(); }
  const grassTex = new THREE.CanvasTexture(gc); grassTex.colorSpace = THREE.SRGBColorSpace;
  inst(grassGeo, new THREE.MeshLambertMaterial({ map: grassTex, alphaTest: 0.5, side: THREE.DoubleSide }), grass);

  // czech hedgehogs (anti-tank)
  const hh = []; for (let i = 0; i < 40; i++) { const x = rand(-75, 75), z = pick([rand(-125, -95), rand(-48, -22), rand(22, 48), rand(95, 125)]); if (!okSpot(x, z)) continue; hh.push([x, heightAt(x, z) + 0.6, z, rand(0, 6), 0, 0, 1]); addCollider(x - 0.7, heightAt(x, z), z - 0.7, x + 0.7, heightAt(x, z) + 1.2, z + 0.7, 'metal'); }
  const beam = new THREE.BoxGeometry(0.15, 0.15, 1.9);
  const hhGeo = mergeGeos([beam.clone().rotateX(0.95), beam.clone().rotateX(-0.95).rotateY(Math.PI / 2), beam.clone().rotateY(Math.PI / 4).rotateX(Math.PI / 2)]);
  inst(hhGeo, rust, hh, hi);

  // barbed wire rolls
  const wire = []; for (let i = 0; i < 30; i++) { const x = rand(-70, 70), z = pick([rand(-115, -100), rand(-42, -28), rand(28, 42), rand(100, 115)]); if (!okSpot(x, z)) continue; wire.push([x, heightAt(x, z) + 0.4, z, rand(-0.3, 0.3), 0, Math.PI / 2, 1]); }
  inst(new THREE.TorusGeometry(0.4, 0.02, 3, 10).scale(1, 1, 1), new THREE.MeshBasicMaterial({ color: 0x2a2a2a, wireframe: true }), wire.flatMap(w => [0, 1, 2, 3, 4, 5].map(k => [w[0] + Math.cos(w[3]) * (k - 2.5) * 0.5, w[1], w[2] + Math.sin(-w[3]) * (k - 2.5) * 0.5, w[3] + Math.PI / 2, 0, 0, 1])));

  // wrecked vehicles (static)
  for (let i = 0; i < 9; i++) {
    const x = rand(-70, 70), z = rand(-120, 120); if (!okSpot(x, z)) continue;
    const y = heightAt(x, z); const g = new THREE.Group(); g.position.set(x, y, z); g.rotation.y = rand(0, 6); g.rotation.z = rand(-0.1, 0.1);
    const car = Math.random() < 0.5;
    if (car) { g.add(new THREE.Mesh(new THREE.BoxGeometry(1.8, 0.8, 4.2), MAT.burnt)); g.children[0].position.y = 0.6; const c2 = new THREE.Mesh(new THREE.BoxGeometry(1.6, 0.6, 2), rust); c2.position.set(0, 1.25, 0.2); g.add(c2); }
    else { const h1 = new THREE.Mesh(new THREE.BoxGeometry(3.2, 1.2, 6.5), MAT.burnt); h1.position.y = 0.8; g.add(h1); const t1 = new THREE.Mesh(new THREE.CylinderGeometry(1.2, 1.3, 0.7, 10), rust); t1.position.set(1.6, 0.4, 3); t1.rotation.z = 1.2; g.add(t1); const br = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 4, 6), MAT.burnt); br.rotation.x = 1.2; br.position.set(-1, 0.6, -4); g.add(br); }
    g.traverse(o => { if (o.isMesh) o.castShadow = hi; });
    scene.add(g);
    const r = car ? 2.2 : 3.4; addCollider(x - r * 0.6, y, z - r * 0.6, x + r * 0.6, y + (car ? 1.5 : 2), z + r * 0.6, 'metal', { walkable: true });
    if (Math.random() < 0.6) world.fires.push({ x, y: y + 1.2, z, size: rand(0.6, 1.2) });
  }
  // telephone poles with wires
  const polePts = [];
  for (let z = -170; z <= 170; z += 22) { const x = -72 + Math.sin(z * 0.02) * 4; const y = heightAt(x, z); const lean = rand(-0.08, 0.08); polePts.push(new THREE.Vector3(x + Math.sin(lean) * 7, y + 7, z)); const p = box(x, y, z, 0.25, 7.5, 0.25, woodM, 'wood', true); p.rotation.z = lean; const cb = box(x, y + 6.8, z, 1.8, 0.12, 0.12, woodM, 'wood', false); cb.rotation.z = lean; }
  const wirePts = []; for (let i = 0; i < polePts.length - 1; i++) { const a = polePts[i], b = polePts[i + 1]; for (let k = 0; k < 8; k++) { const t0 = k / 8, t1 = (k + 1) / 8; const sag = t => Math.sin(t * Math.PI) * 1.2; wirePts.push(new THREE.Vector3().lerpVectors(a, b, t0).setY(a.y + (b.y - a.y) * t0 - sag(t0)), new THREE.Vector3().lerpVectors(a, b, t1).setY(a.y + (b.y - a.y) * t1 - sag(t1))); } }
  scene.add(new THREE.LineSegments(new THREE.BufferGeometry().setFromPoints(wirePts), new THREE.LineBasicMaterial({ color: 0x111111 })));

  // ammo crates & barrels in the field
  for (let i = 0; i < 26; i++) { const x = rand(-75, 75), z = rand(-130, 130); if (!okSpot(x, z)) continue; const y = heightAt(x, z) - 0.05; if (Math.random() < 0.5) box(x, y, z, 1.1, 0.6, 0.7, woodM, 'wood', true, true); else { const m = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.3, 0.9, 10), rust); m.position.set(x, y + 0.45, z); scene.add(m); addCollider(x - 0.3, y, z - 0.3, x + 0.3, y + 0.9, z + 0.3, 'metal'); } }

  // puddles
  const puddleMat = new THREE.MeshPhongMaterial({ color: 0x1d2328, shininess: 120, specular: 0x8899aa, transparent: true, opacity: 0.85 });
  for (let i = 0; i < 40; i++) { const x = rand(-80, 80), z = rand(-160, 160); const p = new THREE.Mesh(new THREE.CircleGeometry(rand(0.8, 2.6), 14), puddleMat); p.rotation.x = -Math.PI / 2; p.scale.y = rand(0.5, 1); p.position.set(x, heightAt(x, z) + 0.04, z); scene.add(p); world.puddles.push(p); }
  for (const c of CRATERS) if (c.r > 3 && Math.random() < 0.7) { const p = new THREE.Mesh(new THREE.CircleGeometry(c.r * 0.45, 14), puddleMat); p.rotation.x = -Math.PI / 2; p.position.set(c.x, heightAt(c.x, c.z) + 0.08, c.z); scene.add(p); }

  // burning fires: extra smoke columns on the horizon
  for (let i = 0; i < 5; i++) world.smokeColumns.push({ x: rand(-150, 150), y: 2, z: pick([-1, 1]) * rand(190, 260), size: rand(3, 6) });
  for (const f of FLAG_POS.slice(0, 3)) world.fires.push({ x: f.x + rand(-14, 14), y: heightAt(f.x, f.z) + 0.3, z: f.z + rand(-14, 14), size: 0.6 });

  // capture-point flags
  FLAG_POS.forEach(fp => {
    const f = makeFlag(); f.position.set(fp.x, heightAt(fp.x, fp.z), fp.z); scene.add(f); world.flags.push(f);
    const ring = new THREE.Mesh(new THREE.RingGeometry(9.6, 10, 48), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.25, side: THREE.DoubleSide, depthWrite: false }));
    ring.rotation.x = -Math.PI / 2; ring.position.set(fp.x, f.position.y + 0.15, fp.z); scene.add(ring);
    G.flags.push({ ...fp, owner: -1, progress: 0, model: f, ring, pos: new THREE.Vector3(fp.x, f.position.y, fp.z) });
  });
  G.flags.forEach(f => { if (f.name === 'A') { f.owner = ALLY; f.progress = 1; } if (f.name === 'C') { f.owner = ENEMY; f.progress = -1; } });

  // ---- rain ----
  const N = hi ? 3200 : 1500; const rg = new THREE.BufferGeometry(); const rp = new Float32Array(N * 6);
  const drops = new Float32Array(N * 3);
  for (let i = 0; i < N; i++) { drops[i * 3] = rand(-25, 25); drops[i * 3 + 1] = rand(0, 22); drops[i * 3 + 2] = rand(-25, 25); }
  rg.setAttribute('position', new THREE.BufferAttribute(rp, 3));
  const rain = new THREE.LineSegments(rg, new THREE.LineBasicMaterial({ color: 0xa8b8c8, transparent: true, opacity: 0.33, depthWrite: false }));
  rain.frustumCulled = false; scene.add(rain);
  world.rain = { mesh: rain, drops, N, pos: rp };
  return world;
}

function mergeGeos(geos) {
  const g = new THREE.BufferGeometry(); let pos = [], nor = [], uv = [], idx = [], off = 0;
  for (const s of geos) {
    const a = s.index ? s.toNonIndexed() : s;
    pos.push(...a.attributes.position.array); nor.push(...a.attributes.normal.array); if (a.attributes.uv) uv.push(...a.attributes.uv.array);
    off += a.attributes.position.count;
  }
  g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3));
  if (uv.length) g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  void idx;
  return g;
}

export function updateWorld(dt, cam) {
  // rain follows camera
  const R = world.rain; if (R) {
    const { drops, N, pos } = R; const fall = 26 * dt, wind = 3 * dt;
    for (let i = 0; i < N; i++) {
      let y = drops[i * 3 + 1] - fall; let x = drops[i * 3] + wind;
      if (y < -4) { y += 26; drops[i * 3 + 2] = rand(-25, 25); x = rand(-25, 25); }
      if (x > 25) x -= 50;
      drops[i * 3] = x; drops[i * 3 + 1] = y;
      const wx = cam.x + x, wy = cam.y + y - 6, wz = cam.z + drops[i * 3 + 2];
      pos[i * 6] = wx; pos[i * 6 + 1] = wy; pos[i * 6 + 2] = wz;
      pos[i * 6 + 3] = wx - 0.12; pos[i * 6 + 4] = wy - 0.75; pos[i * 6 + 5] = wz;
    }
    R.mesh.geometry.attributes.position.needsUpdate = true;
  }
  if (world.sky) { world.sky.position.copy(cam); world.sky.material.uniforms.time.value += dt; }
  if (world.sun && world.sun.castShadow) { world.sun.position.set(cam.x - 40, cam.y + 80, cam.z + 30); world.sun.target.position.set(cam.x, cam.y, cam.z); }
  // lightning
  world.nextLightning -= dt;
  if (world.nextLightning < 0) {
    world.nextLightning = rand(12, 35); world.lightning = 1;
    const dist = rand(0.6, 4); SFX.thunder(dist);
    if (Math.random() < 0.5) setTimeout(() => { world.lightning = 0.8; }, 140);
  }
  if (world.lightning > 0) {
    world.lightning = Math.max(0, world.lightning - dt * 4);
    const f = world.lightning > 0.3 ? world.lightning : 0;
    world.sky.material.uniforms.flash.value = f;
    world.hemi.intensity = 1.25 + f * 3;
    G.scene.fog.color.setRGB(0.345 + f * 0.4, 0.38 + f * 0.4, 0.415 + f * 0.45);
  }
  // waving flags
  const t = G.time;
  for (const f of world.flags) {
    const { cloth, base } = f.userData; const p = cloth.geometry.attributes.position;
    for (let i = 0; i < p.count; i++) { const x = base[i * 3]; p.setZ(i, Math.sin(x * 2.2 - t * 6 + f.position.x) * 0.15 * x * 0.5); p.setY(i, base[i * 3 + 1] - x * 0.06); }
    p.needsUpdate = true;
  }
}
