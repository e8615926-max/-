// Shared game state and small math helpers
import * as THREE from '../lib/three.module.min.js';

export const ALLY = 0, ENEMY = 1;

export const G = {
  scene: null, camera: null, renderer: null,
  vmScene: null, vmCamera: null,
  time: 0, dt: 0,
  units: [], tanks: [], aas: [], drones: [], projectiles: [], grenades: [],
  flags: [],
  player: null,
  mode: 'foot',          // foot | tank | aa | drone
  vehicle: null,         // tank / aa / drone the player controls
  running: false, paused: true, over: false,
  teams: [
    { name: 'Союзники', tickets: 300, morale: 70, color: 0x3d8bff, kills: 0 },
    { name: 'Противник', tickets: 300, morale: 70, color: 0xff3b30, kills: 0 },
  ],
  stats: { kills: 0, deaths: 0, headshots: 0, tanks: 0, drones: 0, revives: 0, earned: 0 },
  settings: { quality: 'high', sens: 1, mobile: false },
  shake: 0,
  nextId: 1,
};

export const rand = (a = 0, b = 1) => a + Math.random() * (b - a);
export const randi = (a, b) => Math.floor(rand(a, b + 1));
export const pick = arr => arr[Math.floor(Math.random() * arr.length)];
export const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
export const lerp = (a, b, t) => a + (b - a) * t;
export const damp = (a, b, k, dt) => a + (b - a) * (1 - Math.exp(-k * dt));
export const angDiff = (a, b) => { let d = b - a; while (d > Math.PI) d -= Math.PI * 2; while (d < -Math.PI) d += Math.PI * 2; return d; };
export const dist2D = (a, b) => Math.hypot(a.x - b.x, a.z - b.z);

export const V3 = (x = 0, y = 0, z = 0) => new THREE.Vector3(x, y, z);
export const tmpV = [new THREE.Vector3(), new THREE.Vector3(), new THREE.Vector3(), new THREE.Vector3(), new THREE.Vector3()];

// Ray vs sphere: returns distance along ray or -1 (dir must be normalized)
export function raySphere(o, d, c, r) {
  const ox = o.x - c.x, oy = o.y - c.y, oz = o.z - c.z;
  const b = ox * d.x + oy * d.y + oz * d.z;
  const cc = ox * ox + oy * oy + oz * oz - r * r;
  const h = b * b - cc;
  if (h < 0) return -1;
  const s = Math.sqrt(h);
  let t = -b - s;
  if (t < 0) t = -b + s;
  return t < 0 ? -1 : t;
}

// Ray vs AABB (slab). Returns {t, nx, ny, nz} or null
const RB = { t: 0, nx: 0, ny: 0, nz: 0 };
let rbMin = 0, rbMax = 0, rbAxis = -1, rbSign = 0;
function slab(o, d, mn, mx, axis) {
  if (d > -1e-8 && d < 1e-8) return !(o < mn || o > mx);
  const inv = 1 / d;
  let t1 = (mn - o) * inv, t2 = (mx - o) * inv, s = -1;
  if (t1 > t2) { const tt = t1; t1 = t2; t2 = tt; s = 1; }
  if (t1 > rbMin) { rbMin = t1; rbAxis = axis; rbSign = s; }
  if (t2 < rbMax) rbMax = t2;
  return rbMin <= rbMax;
}
// NOTE: returns a shared object — copy values before the next call
export function rayBox(o, d, b, maxT) {
  rbMin = 0; rbMax = maxT; rbAxis = -1; rbSign = 0;
  if (!slab(o.x, d.x, b.minX, b.maxX, 0) || !slab(o.y, d.y, b.minY, b.maxY, 1) || !slab(o.z, d.z, b.minZ, b.maxZ, 2)) return null;
  RB.t = rbMin; RB.nx = rbAxis === 0 ? rbSign : 0; RB.ny = rbAxis === 1 ? rbSign : (rbAxis < 0 ? 1 : 0); RB.nz = rbAxis === 2 ? rbSign : 0;
  return RB;
}

// distance from point p to ray segment (o, d, len)
export function pointRayDist(p, o, d, len) {
  const px = p.x - o.x, py = p.y - o.y, pz = p.z - o.z;
  let t = px * d.x + py * d.y + pz * d.z;
  t = clamp(t, 0, len);
  const cx = o.x + d.x * t - p.x, cy = o.y + d.y * t - p.y, cz = o.z + d.z * t - p.z;
  return Math.sqrt(cx * cx + cy * cy + cz * cz);
}

export const CALLSIGNS = ['Медведь', 'Сокол', 'Гром', 'Волк', 'Кедр', 'Рысь', 'Беркут', 'Тайга', 'Шторм', 'Филин', 'Барс', 'Ёж', 'Лис', 'Камень', 'Ворон', 'Север', 'Дед', 'Малой', 'Кузнец', 'Пионер', 'Байкал', 'Урал', 'Казак', 'Сапёр', 'Граф', 'Туман', 'Седой', 'Штык', 'Клён', 'Гарпун'];
export const ENEMY_CALLSIGNS = ['Шакал', 'Гиена', 'Кобра', 'Скорпион', 'Ястреб', 'Варан', 'Оса', 'Кайман', 'Удав', 'Стервятник', 'Барракуда', 'Бизон', 'Паук', 'Тарантул', 'Гадюка', 'Носорог', 'Пума', 'Койот', 'Мангуст', 'Кондор'];
