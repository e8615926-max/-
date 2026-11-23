// Particles, tracers, flashes, decals
import * as THREE from '../lib/three.module.min.js';
import { G, rand, clamp } from './state.js';
import { heightAt } from './world.js';

const VS = `attribute float size; attribute float alpha; attribute vec3 color; varying float vA; varying vec3 vC; uniform float scale;
void main(){ vA=alpha; vC=color; vec4 mv=modelViewMatrix*vec4(position,1.0); gl_PointSize=clamp(size*scale/max(-mv.z,0.1), 1.0, 900.0); gl_Position=projectionMatrix*mv; }`;
const FS = `varying float vA; varying vec3 vC; uniform float soft;
void main(){ vec2 c=gl_PointCoord-0.5; float d=length(c)*2.0; if(d>1.0) discard; float a=pow(1.0-d, soft); gl_FragColor=vec4(vC, a*vA); }`;

class Particles {
  constructor(max, additive, soft) {
    this.max = max; this.n = 0;
    this.p = new Float32Array(max * 3); this.v = new Float32Array(max * 3); this.c = new Float32Array(max * 3);
    this.s = new Float32Array(max); this.a = new Float32Array(max); this.life = new Float32Array(max); this.age = new Float32Array(max);
    this.grow = new Float32Array(max); this.grav = new Float32Array(max); this.drag = new Float32Array(max); this.a0 = new Float32Array(max); this.fade = new Float32Array(max);
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(this.p, 3).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('color', new THREE.BufferAttribute(this.c, 3).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('size', new THREE.BufferAttribute(this.s, 1).setUsage(THREE.DynamicDrawUsage));
    g.setAttribute('alpha', new THREE.BufferAttribute(this.a, 1).setUsage(THREE.DynamicDrawUsage));
    this.mat = new THREE.ShaderMaterial({ vertexShader: VS, fragmentShader: FS, transparent: true, depthWrite: false, blending: additive ? THREE.AdditiveBlending : THREE.NormalBlending, uniforms: { scale: { value: 400 }, soft: { value: soft } } });
    this.mesh = new THREE.Points(g, this.mat); this.mesh.frustumCulled = false; this.geo = g;
  }
  add(x, y, z, vx, vy, vz, size, life, r, gg, b, alpha = 1, grow = 0, grav = 0, drag = 0, fade = 1) {
    let i = this.n; if (i >= this.max) { i = Math.floor(Math.random() * this.max); } else this.n++;
    this.p[i * 3] = x; this.p[i * 3 + 1] = y; this.p[i * 3 + 2] = z; this.v[i * 3] = vx; this.v[i * 3 + 1] = vy; this.v[i * 3 + 2] = vz;
    this.c[i * 3] = r; this.c[i * 3 + 1] = gg; this.c[i * 3 + 2] = b; this.s[i] = size; this.a[i] = alpha; this.a0[i] = alpha;
    this.life[i] = life; this.age[i] = 0; this.grow[i] = grow; this.grav[i] = grav; this.drag[i] = drag; this.fade[i] = fade;
  }
  update(dt) {
    let i = 0;
    while (i < this.n) {
      this.age[i] += dt;
      if (this.age[i] >= this.life[i]) { this.swap(i, --this.n); continue; }
      const k = i * 3; const dr = Math.exp(-this.drag[i] * dt);
      this.v[k] *= dr; this.v[k + 1] = this.v[k + 1] * dr - this.grav[i] * dt; this.v[k + 2] *= dr;
      this.p[k] += this.v[k] * dt; this.p[k + 1] += this.v[k + 1] * dt; this.p[k + 2] += this.v[k + 2] * dt;
      if (this.grav[i] > 0) { const h = heightAt(this.p[k], this.p[k + 2]); if (this.p[k + 1] < h + 0.03) { this.p[k + 1] = h + 0.03; this.v[k] *= 0.3; this.v[k + 1] = Math.abs(this.v[k + 1]) * 0.15; this.v[k + 2] *= 0.3; } }
      this.s[i] += this.grow[i] * dt;
      const t = this.age[i] / this.life[i];
      this.a[i] = this.a0[i] * (this.fade[i] === 2 ? Math.min(1, t * 6) * (1 - t) : (1 - Math.pow(t, 1.5)));
      i++;
    }
    this.geo.setDrawRange(0, this.n);
    for (const n of ['position', 'color', 'size', 'alpha']) this.geo.attributes[n].needsUpdate = true;
  }
  swap(i, j) {
    if (i === j) return;
    for (const arr of [this.p, this.v, this.c]) { arr[i * 3] = arr[j * 3]; arr[i * 3 + 1] = arr[j * 3 + 1]; arr[i * 3 + 2] = arr[j * 3 + 2]; }
    for (const arr of [this.s, this.a, this.life, this.age, this.grow, this.grav, this.drag, this.a0, this.fade]) arr[i] = arr[j];
  }
}

let glow, smoke, tracerMesh, tracerPos, tracerCol;
const tracers = [];
const MAX_TR = 160;
const lights = [];
const decals = []; let decalMesh, decalIdx = 0; const MAX_DECALS = 160;
const dummy = new THREE.Object3D();
let flashes = [];

export function initEffects(scene) {
  glow = new Particles(2500, true, 1.6); smoke = new Particles(2600, false, 1.2);
  scene.add(smoke.mesh); scene.add(glow.mesh);
  // tracers
  const g = new THREE.BufferGeometry(); tracerPos = new Float32Array(MAX_TR * 6); tracerCol = new Float32Array(MAX_TR * 6);
  g.setAttribute('position', new THREE.BufferAttribute(tracerPos, 3)); g.setAttribute('color', new THREE.BufferAttribute(tracerCol, 3));
  tracerMesh = new THREE.LineSegments(g, new THREE.LineBasicMaterial({ vertexColors: true, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false }));
  tracerMesh.frustumCulled = false; scene.add(tracerMesh);
  // pooled dynamic lights (fixed count → no shader recompiles)
  for (let i = 0; i < 4; i++) { const l = new THREE.PointLight(0xffaa55, 0, 30, 1.6); scene.add(l); lights.push({ l, t: 0, dur: 1, peak: 0 }); }
  // decals (scorch/bullet holes) as instanced quads
  const dg = new THREE.CircleGeometry(0.5, 10);
  decalMesh = new THREE.InstancedMesh(dg, new THREE.MeshBasicMaterial({ color: 0x0c0a08, transparent: true, opacity: 0.8, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4 }), MAX_DECALS);
  for (let i = 0; i < MAX_DECALS; i++) decalMesh.setColorAt(i, _col.setHex(0x0c0a08));
  decalMesh.count = 0; decalMesh.frustumCulled = false; scene.add(decalMesh);
}

export function setParticleScale(h, fov) {
  const s = h / (2 * Math.tan(fov * Math.PI / 360));
  glow.mat.uniforms.scale.value = s; smoke.mat.uniforms.scale.value = s;
}

function flashLight(pos, color, peak, dur, dist = 30) {
  let best = lights[0]; for (const L of lights) if (L.t <= 0 || L.peak * (L.t / L.dur) < best.peak * (best.t / best.dur)) best = L;
  best.l.position.copy(pos); best.l.color.setHex(color); best.l.distance = dist; best.t = dur; best.dur = dur; best.peak = peak; best.l.intensity = peak;
}

export function muzzleFlash(pos, dir, big = 1, light = true) {
  for (let i = 0; i < 5; i++) { const s = rand(0.2, 0.6); glow.add(pos.x + dir.x * s, pos.y + dir.y * s, pos.z + dir.z * s, dir.x * 2, dir.y * 2, dir.z * 2, rand(0.25, 0.5) * big, 0.05, 1, 0.75, 0.35, 1); }
  glow.add(pos.x, pos.y, pos.z, 0, 0, 0, 0.9 * big, 0.04, 1, 0.85, 0.5, 1);
  smoke.add(pos.x + dir.x * 0.3, pos.y, pos.z + dir.z * 0.3, dir.x * 0.6 + rand(-0.2, 0.2), 0.3, dir.z * 0.6, 0.3 * big, 0.8, 0.55, 0.55, 0.55, 0.25, 0.8);
  if (light) flashLight(pos, 0xffb060, 3 * big, 0.06, 12 * big);
}

export function tracer(a, b, color = [1, 0.75, 0.35], speed = 600) {
  const len = a.distanceTo(b);
  tracers.push({ ax: a.x, ay: a.y, az: a.z, dx: (b.x - a.x) / len, dy: (b.y - a.y) / len, dz: (b.z - a.z) / len, len, t: 0, speed, col: color });
  if (tracers.length > MAX_TR) tracers.shift();
}

export function impactFx(p, n, mat) {
  const nx = n.x, ny = n.y, nz = n.z;
  if (mat === 'flesh') { blood(p, n, 1); return; }
  if (mat === 'metal') { for (let i = 0; i < 8; i++) glow.add(p.x, p.y, p.z, nx * 3 + rand(-3, 3), ny * 3 + rand(0, 4), nz * 3 + rand(-3, 3), 0.08, rand(0.15, 0.35), 1, 0.8, 0.4, 1, 0, 9.8, 1); }
  const dc = mat === 'dirt' || mat === 'sand' ? [0.3, 0.25, 0.18] : mat === 'wood' ? [0.4, 0.3, 0.2] : [0.55, 0.53, 0.5];
  for (let i = 0; i < 6; i++) smoke.add(p.x, p.y, p.z, nx * rand(1, 3) + rand(-1, 1), ny * rand(1, 3) + rand(0, 2), nz * rand(1, 3) + rand(-1, 1), rand(0.12, 0.3), rand(0.4, 0.9), dc[0], dc[1], dc[2], 0.8, 0.4, 6, 2);
  smoke.add(p.x, p.y, p.z, nx * 0.5, 0.4, nz * 0.5, 0.4, 1.2, dc[0] * 1.3, dc[1] * 1.3, dc[2] * 1.3, 0.35, 1.2, 0, 1);
  if (mat !== 'dirt') decal(p, n, 0.07);
}

export function blood(p, dir, amount = 1) {
  for (let i = 0; i < 10 * amount; i++) smoke.add(p.x, p.y, p.z, dir.x * rand(0.5, 3) + rand(-1, 1), rand(-0.5, 2), dir.z * rand(0.5, 3) + rand(-1, 1), rand(0.05, 0.14), rand(0.4, 0.9), rand(0.35, 0.5), 0.02, 0.02, 1, 0, 9.8, 0.5);
  smoke.add(p.x, p.y, p.z, dir.x, 0.2, dir.z, 0.25, 0.4, 0.5, 0.05, 0.05, 0.6, 1.2, 0, 2);
}
export function bloodPool(p) { decalAt(p.x, heightAt(p.x, p.z) + 0.03, p.z, 0, 1, 0, rand(0.5, 0.9), 0x3a0505); }

export function explosionFx(pos, size = 1) {
  const s = size;
  flashLight(pos, 0xff9944, 12 * s, 0.5, 45 * s);
  for (let i = 0; i < 40 * s; i++) { const a = rand(0, 6.28), b = rand(-0.2, 1.4); const sp = rand(2, 9) * s; glow.add(pos.x, pos.y + 0.3, pos.z, Math.cos(a) * Math.cos(b) * sp, Math.sin(b) * sp, Math.sin(a) * Math.cos(b) * sp, rand(0.8, 2) * s, rand(0.25, 0.6), 1, rand(0.45, 0.7), 0.15, 1, 2, 0, 3); }
  for (let i = 0; i < 26 * s; i++) { const a = rand(0, 6.28); const sp = rand(1, 5) * s; smoke.add(pos.x, pos.y + 0.5, pos.z, Math.cos(a) * sp, rand(1, 6) * s, Math.sin(a) * sp, rand(1, 2.4) * s, rand(2.5, 6), rand(0.1, 0.2), rand(0.1, 0.18), rand(0.08, 0.15), 0.85, 1.5 * s, -0.4, 1.2, 2); }
  for (let i = 0; i < 30 * s; i++) { const a = rand(0, 6.28); const sp = rand(4, 16) * s; smoke.add(pos.x, pos.y + 0.3, pos.z, Math.cos(a) * sp * 0.6, rand(4, 14) * s, Math.sin(a) * sp * 0.6, rand(0.08, 0.2), rand(1, 2.2), 0.15, 0.12, 0.08, 1, 0, 12, 0.3); }
  for (let i = 0; i < 16 * s; i++) glow.add(pos.x, pos.y + 0.3, pos.z, rand(-12, 12), rand(4, 16), rand(-12, 12), 0.1, rand(0.6, 1.6), 1, 0.7, 0.3, 1, 0, 9.8, 0.4);
  // ground dust ring
  for (let i = 0; i < 20; i++) { const a = i / 20 * 6.28; smoke.add(pos.x, pos.y + 0.2, pos.z, Math.cos(a) * 9 * s, 0.5, Math.sin(a) * 9 * s, 1.2 * s, 1.6, 0.35, 0.3, 0.24, 0.6, 2 * s, 0, 2.5); }
  const gy = heightAt(pos.x, pos.z);
  if (pos.y - gy < 1.5) decalAt(pos.x, gy + 0.04, pos.z, 0, 1, 0, 1.6 * s, 0x0a0806);
  G.shake = Math.max(G.shake, clamp(1.2 * s - G.camera.position.distanceTo(pos) / 40, 0, 1.5));
}

export function flakFx(pos) {
  flashLight(pos, 0xffaa66, 3, 0.15, 20);
  for (let i = 0; i < 6; i++) glow.add(pos.x, pos.y, pos.z, rand(-4, 4), rand(-4, 4), rand(-4, 4), rand(0.5, 1), 0.15, 1, 0.7, 0.3);
  for (let i = 0; i < 4; i++) smoke.add(pos.x, pos.y, pos.z, rand(-1, 1), rand(-1, 1), rand(-1, 1), rand(1, 1.8), rand(2, 4), 0.08, 0.08, 0.08, 0.9, 0.6, 0, 0.8);
}

export function smokeTrail(p, big = 1) {
  smoke.add(p.x, p.y, p.z, rand(-0.3, 0.3), rand(0, 0.5), rand(-0.3, 0.3), 0.35 * big, rand(1, 2), 0.6, 0.6, 0.6, 0.45, 0.9, -0.2, 1);
  glow.add(p.x, p.y, p.z, 0, 0, 0, 0.35 * big, 0.06, 1, 0.6, 0.2);
}

export function fireFx(p, size, dt) {
  if (Math.random() < 14 * dt * size) glow.add(p.x + rand(-0.4, 0.4) * size, p.y, p.z + rand(-0.4, 0.4) * size, rand(-0.3, 0.3), rand(1, 2.4), rand(-0.3, 0.3), rand(0.5, 1.1) * size, rand(0.35, 0.7), 1, rand(0.35, 0.55), 0.1, 0.9, -0.5);
  if (Math.random() < 6 * dt * size) smoke.add(p.x, p.y + 1 * size, p.z, rand(-0.3, 0.3) + 0.6, rand(1.5, 3), rand(-0.3, 0.3), rand(0.8, 1.5) * size, rand(4, 8), 0.07, 0.07, 0.07, 0.7, 1.2, -0.1, 0.4, 2);
  if (Math.random() < 0.5 * dt) flashLight(p, 0xff7a30, 1.2, 0.3, 14);
}
export function smokeColumnFx(p, size, dt) {
  if (Math.random() < 3 * dt) smoke.add(p.x + rand(-2, 2), p.y + rand(0, 4), p.z + rand(-2, 2), 1.2, rand(3, 5), 0.2, rand(4, 7) * size * 0.4, rand(14, 22), 0.08, 0.08, 0.09, 0.6, 1.8, -0.05, 0.1, 2);
}
export function dustPuff(p, n = 3, col = [0.32, 0.28, 0.22]) {
  for (let i = 0; i < n; i++) smoke.add(p.x + rand(-0.4, 0.4), p.y + 0.1, p.z + rand(-0.4, 0.4), rand(-0.6, 0.6), rand(0.2, 0.8), rand(-0.6, 0.6), rand(0.4, 0.9), rand(0.8, 1.6), col[0], col[1], col[2], 0.35, 0.8, 0, 1);
}
export function splash(p) { for (let i = 0; i < 3; i++) smoke.add(p.x, p.y + 0.05, p.z, rand(-0.8, 0.8), rand(1, 2), rand(-0.8, 0.8), 0.06, 0.35, 0.4, 0.42, 0.45, 0.6, 0, 9.8, 0.2); }
export function casing(p, dir) { glow.add(p.x, p.y, p.z, dir.x * 2 + rand(-0.4, 0.4), rand(1.5, 2.5), dir.z * 2 + rand(-0.4, 0.4), 0.04, 0.6, 0.6, 0.45, 0.15, 0.8, 0, 9.8, 0.2); }
export function healFx(p) { for (let i = 0; i < 2; i++) glow.add(p.x + rand(-0.4, 0.4), p.y + rand(0.2, 1.6), p.z + rand(-0.4, 0.4), 0, rand(0.4, 1), 0, rand(0.12, 0.25), rand(0.6, 1), 0.3, 1, 0.4, 0.8); }
export function sparks(p, n = 10) { for (let i = 0; i < n; i++) glow.add(p.x, p.y, p.z, rand(-5, 5), rand(1, 6), rand(-5, 5), 0.08, rand(0.3, 0.7), 1, 0.75, 0.3, 1, 0, 9.8, 0.5); }

function decal(p, n, size) { decalAt(p.x + n.x * 0.02, p.y + n.y * 0.02, p.z + n.z * 0.02, n.x, n.y, n.z, size); }
const _up = new THREE.Vector3(0, 0, 1); const _nn = new THREE.Vector3(); const _col = new THREE.Color();
function decalAt(x, y, z, nx, ny, nz, size, color = 0x0c0a08) {
  dummy.position.set(x, y, z); _nn.set(nx, ny, nz); dummy.quaternion.setFromUnitVectors(_up, _nn); dummy.rotateZ(rand(0, 6));
  dummy.scale.setScalar(size); dummy.updateMatrix();
  decalMesh.setMatrixAt(decalIdx, dummy.matrix); decalMesh.setColorAt(decalIdx, _col.setHex(color));
  decalIdx = (decalIdx + 1) % MAX_DECALS; decalMesh.count = Math.min(MAX_DECALS, decalMesh.count + 1);
  decalMesh.instanceMatrix.needsUpdate = true; if (decalMesh.instanceColor) decalMesh.instanceColor.needsUpdate = true;
}

export function updateEffects(dt) {
  glow.update(dt); smoke.update(dt);
  let n = 0;
  for (let i = tracers.length - 1; i >= 0; i--) {
    const T = tracers[i]; T.t += dt * T.speed;
    if (T.t - 6 > T.len) { tracers.splice(i, 1); continue; }
    const h = Math.min(T.t, T.len), tl = Math.max(0, T.t - (T.speed > 300 ? 7 : 3));
    const k = n * 6;
    tracerPos[k] = T.ax + T.dx * tl; tracerPos[k + 1] = T.ay + T.dy * tl; tracerPos[k + 2] = T.az + T.dz * tl;
    tracerPos[k + 3] = T.ax + T.dx * h; tracerPos[k + 4] = T.ay + T.dy * h; tracerPos[k + 5] = T.az + T.dz * h;
    tracerCol[k] = T.col[0] * 0.15; tracerCol[k + 1] = T.col[1] * 0.15; tracerCol[k + 2] = T.col[2] * 0.15;
    tracerCol[k + 3] = T.col[0]; tracerCol[k + 4] = T.col[1]; tracerCol[k + 5] = T.col[2];
    n++; if (n >= MAX_TR) break;
  }
  tracerMesh.geometry.setDrawRange(0, n * 2);
  tracerMesh.geometry.attributes.position.needsUpdate = true; tracerMesh.geometry.attributes.color.needsUpdate = true;
  for (const L of lights) { if (L.t > 0) { L.t -= dt; L.l.intensity = Math.max(0, L.peak * (L.t / L.dur)); } else L.l.intensity = 0; }
  void flashes;
}
