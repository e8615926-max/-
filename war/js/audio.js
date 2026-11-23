// Procedural audio: every sound is synthesized with WebAudio
import { G, rand, pick, clamp } from './state.js';

let ac = null, master, sfxBus, ambBus, reverb, reverbSend, noiseBuf, pinkBuf;
let voices = 0;
const MAX_VOICES = 34;
const listenerPos = { x: 0, y: 0, z: 0 };
let speechVoice = null;

export const audio = {
  get ctx() { return ac; },
  ready: false,
  muffle: 0,
};

function makeNoise(seconds, pink) {
  const len = ac.sampleRate * seconds;
  const b = ac.createBuffer(1, len, ac.sampleRate);
  const d = b.getChannelData(0);
  let b0 = 0, b1 = 0, b2 = 0;
  for (let i = 0; i < len; i++) {
    const w = Math.random() * 2 - 1;
    if (pink) {
      b0 = 0.99765 * b0 + w * 0.099046; b1 = 0.963 * b1 + w * 0.2965164; b2 = 0.57 * b2 + w * 1.0526913;
      d[i] = (b0 + b1 + b2 + w * 0.1848) * 0.18;
    } else d[i] = w;
  }
  return b;
}

function makeImpulse(seconds, decay) {
  const len = ac.sampleRate * seconds;
  const b = ac.createBuffer(2, len, ac.sampleRate);
  for (let c = 0; c < 2; c++) {
    const d = b.getChannelData(c);
    for (let i = 0; i < len; i++) {
      const t = i / len;
      // early slap echoes (outdoor buildings) + diffuse tail
      let v = (Math.random() * 2 - 1) * Math.pow(1 - t, decay);
      if (i > ac.sampleRate * 0.09 && i < ac.sampleRate * 0.1) v *= 3;
      if (i > ac.sampleRate * 0.23 && i < ac.sampleRate * 0.24) v *= 2;
      d[i] = v;
    }
  }
  return b;
}

export function initAudio() {
  if (ac) { ac.resume(); return; }
  const AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) return;
  ac = new AC();
  master = ac.createGain(); master.gain.value = 0.9;
  const comp = ac.createDynamicsCompressor();
  comp.threshold.value = -14; comp.ratio.value = 5; comp.attack.value = 0.003; comp.release.value = 0.25;
  audio.muffleFilter = ac.createBiquadFilter();
  audio.muffleFilter.type = 'lowpass'; audio.muffleFilter.frequency.value = 20000;
  master.connect(audio.muffleFilter); audio.muffleFilter.connect(comp); comp.connect(ac.destination);
  sfxBus = ac.createGain(); sfxBus.connect(master);
  ambBus = ac.createGain(); ambBus.gain.value = 0.85; ambBus.connect(master);
  reverb = ac.createConvolver(); reverb.buffer = makeImpulse(2.6, 3.2);
  reverbSend = ac.createGain(); reverbSend.gain.value = 0.55;
  reverbSend.connect(reverb); reverb.connect(master);
  noiseBuf = makeNoise(2, false);
  pinkBuf = makeNoise(4, true);
  audio.ready = true;
  startAmbience();
  pickVoice();
  if (window.speechSynthesis) speechSynthesis.onvoiceschanged = pickVoice;
}

function pickVoice() {
  if (!window.speechSynthesis) return;
  const vs = speechSynthesis.getVoices();
  speechVoice = vs.find(v => /ru/i.test(v.lang) && /male|муж|dmitri|yuri|pavel/i.test(v.name)) || vs.find(v => /ru/i.test(v.lang)) || null;
}

export function setListener(pos, fwd, up) {
  if (!ac) return;
  listenerPos.x = pos.x; listenerPos.y = pos.y; listenerPos.z = pos.z;
  const l = ac.listener, t = ac.currentTime;
  if (l.positionX) {
    l.positionX.setTargetAtTime(pos.x, t, 0.02); l.positionY.setTargetAtTime(pos.y, t, 0.02); l.positionZ.setTargetAtTime(pos.z, t, 0.02);
    l.forwardX.setTargetAtTime(fwd.x, t, 0.02); l.forwardY.setTargetAtTime(fwd.y, t, 0.02); l.forwardZ.setTargetAtTime(fwd.z, t, 0.02);
    l.upX.value = up.x; l.upY.value = up.y; l.upZ.value = up.z;
  } else {
    l.setPosition(pos.x, pos.y, pos.z); l.setOrientation(fwd.x, fwd.y, fwd.z, up.x, up.y, up.z);
  }
}

export function setMuffle(amount) {
  if (!ac) return;
  audio.muffle = amount;
  audio.muffleFilter.frequency.setTargetAtTime(20000 - amount * 19300, ac.currentTime, 0.08);
}

function distTo(p) {
  if (!p) return 0;
  const dx = p.x - listenerPos.x, dy = p.y - listenerPos.y, dz = p.z - listenerPos.z;
  return Math.sqrt(dx * dx + dy * dy + dz * dz);
}

// Output chain: (positional) panner -> sfx bus (+ reverb send)
function out(pos, wet = 0.2, ref = 6) {
  const g = ac.createGain();
  if (pos) {
    const p = ac.createPanner();
    p.panningModel = 'equalpower'; p.distanceModel = 'inverse';
    p.refDistance = ref; p.rolloffFactor = 1.1; p.maxDistance = 1000;
    if (p.positionX) { p.positionX.value = pos.x; p.positionY.value = pos.y; p.positionZ.value = pos.z; }
    else p.setPosition(pos.x, pos.y, pos.z);
    g.connect(p); p.connect(sfxBus);
    if (wet > 0) { const w = ac.createGain(); w.gain.value = wet; p.connect(w); w.connect(reverbSend); }
  } else {
    g.connect(sfxBus);
    if (wet > 0) { const w = ac.createGain(); w.gain.value = wet; g.connect(w); w.connect(reverbSend); }
  }
  return g;
}

function voice(dur) {
  if (voices >= MAX_VOICES) return false;
  voices++; setTimeout(() => voices--, dur * 1000 + 60);
  return true;
}

function noise(t, dur, dest, rate = 1, buf = noiseBuf) {
  const s = ac.createBufferSource(); s.buffer = buf; s.playbackRate.value = rate;
  s.loop = true;
  s.start(t, Math.random() * 1.5); s.stop(t + dur);
  s.connect(dest); return s;
}
function filt(type, f, q = 1) { const b = ac.createBiquadFilter(); b.type = type; b.frequency.value = f; b.Q.value = q; return b; }
function env(g, t, a, peak, d, end = 0.0001) {
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(peak, t + a);
  g.gain.exponentialRampToValueAtTime(end, t + a + d);
}
function osc(type, f, t, dur, dest) { const o = ac.createOscillator(); o.type = type; o.frequency.value = f; o.start(t); o.stop(t + dur); o.connect(dest); return o; }

// ---------------- Weapons ----------------
const GUN = {
  pistol: { lp: 5200, bp: 1800, dec: 0.12, thump: 110, vol: 0.55, tail: 0.25 },
  rifle: { lp: 6500, bp: 1300, dec: 0.16, thump: 85, vol: 0.75, tail: 0.35 },
  smg: { lp: 6000, bp: 1600, dec: 0.1, thump: 95, vol: 0.6, tail: 0.25 },
  shotgun: { lp: 4200, bp: 900, dec: 0.25, thump: 60, vol: 0.95, tail: 0.5 },
  sniper: { lp: 7500, bp: 1100, dec: 0.3, thump: 55, vol: 1.05, tail: 0.7 },
  mg: { lp: 5600, bp: 1000, dec: 0.18, thump: 70, vol: 0.85, tail: 0.4 },
  autocannon: { lp: 3500, bp: 600, dec: 0.25, thump: 45, vol: 1.0, tail: 0.6 },
  aa: { lp: 4000, bp: 700, dec: 0.2, thump: 50, vol: 0.95, tail: 0.55 },
};

export function shot(kind, pos, isPlayer) {
  if (!ac) return;
  const d = isPlayer ? 0 : distTo(pos);
  if (d > 420) return;
  const P = GUN[kind] || GUN.rifle;
  if (!voice(P.dec + 0.4)) return;
  const t = ac.currentTime;
  const o = out(isPlayer ? null : pos, P.tail * (0.6 + d / 150), 8);
  const far = clamp(d / 260, 0, 1);
  // crack
  const g1 = ac.createGain(); env(g1, t, 0.001, P.vol * (isPlayer ? 1 : 1.6), P.dec);
  const lp = filt('lowpass', P.lp * (1 - far * 0.8)); lp.connect(g1); g1.connect(o);
  noise(t, P.dec + 0.05, lp, rand(0.85, 1.15));
  // body
  const g2 = ac.createGain(); env(g2, t, 0.002, P.vol * 0.8, P.dec * 0.7);
  const bp = filt('bandpass', P.bp * rand(0.9, 1.1), 0.8); bp.connect(g2); g2.connect(o);
  noise(t, P.dec, bp);
  // thump
  const g3 = ac.createGain(); env(g3, t, 0.002, P.vol * (isPlayer ? 1.1 : 0.6), 0.12);
  const th = osc('sine', P.thump * 2, t, 0.2, g3); th.frequency.exponentialRampToValueAtTime(P.thump * 0.5, t + 0.12); g3.connect(o);
  if (isPlayer) { // mechanical clack
    const g4 = ac.createGain(); env(g4, t + 0.03, 0.001, 0.12, 0.03);
    const hp = filt('highpass', 3000); hp.connect(g4); g4.connect(o); noise(t + 0.03, 0.05, hp);
  }
}

export function emptyClick() {
  if (!ac) return; const t = ac.currentTime; const o = out(null, 0);
  const g = ac.createGain(); env(g, t, 0.001, 0.3, 0.025); const hp = filt('highpass', 2500); hp.connect(g); g.connect(o); noise(t, 0.04, hp);
}

function click(t, f, vol, o) {
  const g = ac.createGain(); env(g, t, 0.001, vol, 0.04); const b = filt('bandpass', f, 3); b.connect(g); g.connect(o); noise(t, 0.06, b);
}
export function reloadSound(dur, kind) {
  if (!ac) return; const t = ac.currentTime; const o = out(null, 0.05);
  if (kind === 'shotgun') {
    for (let i = 0; i < 4; i++) click(t + 0.25 + i * (dur - 0.6) / 4, 1800, 0.35, o);
    click(t + dur - 0.25, 900, 0.5, o); click(t + dur - 0.15, 1400, 0.5, o);
    return;
  }
  if (kind === 'rocket') { click(t + 0.3, 600, 0.5, o); click(t + dur - 0.4, 800, 0.6, o); click(t + dur - 0.2, 2000, 0.4, o); return; }
  click(t + 0.15, 1400, 0.45, o); // mag release
  click(t + 0.22, 700, 0.35, o); // mag out
  click(t + dur * 0.62, 900, 0.55, o); // mag in
  click(t + dur * 0.66, 2200, 0.3, o);
  click(t + dur - 0.22, 1600, 0.5, o); // bolt back
  click(t + dur - 0.12, 1100, 0.6, o); // bolt forward
}

export function shellCasing() {
  if (!ac || Math.random() < 0.5) return; const t = ac.currentTime + rand(0.25, 0.45); const o = out(null, 0);
  const g = ac.createGain(); env(g, t, 0.001, 0.05, 0.08); osc('sine', rand(3500, 5200), t, 0.1, g); g.connect(o);
}

export function whiz(pos) {
  if (!ac || !voice(0.3)) return; const t = ac.currentTime; const o = out(pos, 0.1, 3);
  const g = ac.createGain(); env(g, t, 0.005, 0.7, 0.12);
  const bp = filt('bandpass', 3000, 2); bp.frequency.exponentialRampToValueAtTime(900, t + 0.15); bp.connect(g); g.connect(o);
  noise(t, 0.2, bp, 1.4);
  const g2 = ac.createGain(); env(g2, t, 0.001, 0.5, 0.03); const hp = filt('highpass', 4000); hp.connect(g2); g2.connect(o); noise(t, 0.05, hp);
}

export function impact(pos, mat) {
  if (!ac) return; const d = distTo(pos); if (d > 60 || !voice(0.3)) return;
  const t = ac.currentTime; const o = out(pos, 0.1, 3);
  if (mat === 'metal') {
    const g = ac.createGain(); env(g, t, 0.001, 0.4, 0.25);
    osc('sine', rand(1800, 3200), t, 0.3, g); osc('triangle', rand(4000, 5500), t, 0.15, g); g.connect(o);
    if (Math.random() < 0.4) ricochet(pos);
  } else if (mat === 'flesh') {
    const g = ac.createGain(); env(g, t, 0.002, 0.8, 0.09); const lp = filt('lowpass', 700); lp.connect(g); g.connect(o); noise(t, 0.12, lp, 0.6);
  } else {
    const g = ac.createGain(); env(g, t, 0.001, 0.35, 0.07); const bp = filt('bandpass', mat === 'wood' ? 900 : 1500, 1.2); bp.connect(g); g.connect(o); noise(t, 0.1, bp);
  }
}
export function ricochet(pos) {
  if (!ac || !voice(0.4)) return; const t = ac.currentTime; const o = out(pos, 0.2, 4);
  const g = ac.createGain(); env(g, t, 0.003, 0.25, 0.3); const s = osc('sine', rand(2800, 4200), t, 0.35, g); s.frequency.exponentialRampToValueAtTime(rand(700, 1200), t + 0.3); g.connect(o);
}
export function hitMarker(kill) {
  if (!ac) return; const t = ac.currentTime; const o = out(null, 0);
  const g = ac.createGain(); env(g, t, 0.001, kill ? 0.3 : 0.18, kill ? 0.25 : 0.06);
  osc('square', kill ? 1300 : 2200, t, 0.3, g); if (kill) osc('sine', 1950, t + 0.06, 0.25, g); const lp = filt('lowpass', 5000); g.connect(lp); lp.connect(o);
}
export function coin() {
  if (!ac) return; const t = ac.currentTime; const o = out(null, 0.1);
  [1568, 2093, 2637].forEach((f, i) => { const g = ac.createGain(); env(g, t + i * 0.07, 0.002, 0.18, 0.3); osc('triangle', f, t + i * 0.07, 0.35, g); g.connect(o); });
}
export function uiClick() {
  if (!ac) return; const t = ac.currentTime; const o = out(null, 0);
  const g = ac.createGain(); env(g, t, 0.001, 0.15, 0.04); osc('square', 900, t, 0.05, g); g.connect(o);
}
export function denied() {
  if (!ac) return; const t = ac.currentTime; const o = out(null, 0);
  const g = ac.createGain(); env(g, t, 0.001, 0.15, 0.25); osc('sawtooth', 180, t, 0.3, g); const lp = filt('lowpass', 1200); g.connect(lp); lp.connect(o);
}

// ---------------- Explosions ----------------
export function explosion(pos, size = 1) {
  if (!ac) return; const d = distTo(pos); if (d > 700) return;
  const t = ac.currentTime + d / 343 * 0.25; // slight delay with distance
  const o = out(pos, 0.9, 14 * size);
  const far = clamp(d / 300, 0, 1);
  const g = ac.createGain(); env(g, t, 0.004, 1.6 * size, 1.4 + size * 0.6);
  const lp = filt('lowpass', 2400 * (1 - far * 0.75)); lp.frequency.exponentialRampToValueAtTime(180, t + 1.4); lp.connect(g); g.connect(o);
  noise(t, 2.5, lp, 0.7);
  const g2 = ac.createGain(); env(g2, t, 0.004, 1.4 * size, 0.9);
  const sub = osc('sine', 90, t, 1.2, g2); sub.frequency.exponentialRampToValueAtTime(28, t + 0.9); g2.connect(o);
  // debris crackle
  if (d < 120) for (let i = 0; i < 6; i++) {
    const tt = t + 0.15 + Math.random() * 0.9; const gg = ac.createGain(); env(gg, tt, 0.001, 0.15 * size, 0.05);
    const hp = filt('bandpass', rand(1200, 3500), 2); hp.connect(gg); gg.connect(o); noise(tt, 0.08, hp);
  }
  if (d < 14) tinnitus(1 - d / 14);
}

let tinnT = 0;
export function tinnitus(k) {
  if (!ac || ac.currentTime < tinnT) return; tinnT = ac.currentTime + 2;
  const t = ac.currentTime; const g = ac.createGain(); env(g, t, 0.05, 0.09 * k + 0.02, 3.5);
  osc('sine', 3900, t, 4, g); g.connect(master);
  setMuffle(0.85 * k + 0.1);
  setTimeout(() => setMuffle(0), 2600);
}

export function whistle(pos, dur = 1.6) {
  if (!ac || !voice(dur)) return; const t = ac.currentTime; const o = out(pos, 0.4, 20);
  const g = ac.createGain(); g.gain.setValueAtTime(0.001, t); g.gain.exponentialRampToValueAtTime(0.25, t + dur * 0.8); g.gain.exponentialRampToValueAtTime(0.001, t + dur);
  const s = osc('sine', 1500, t, dur, g); s.frequency.exponentialRampToValueAtTime(500, t + dur); g.connect(o);
}

export function grenadePin() {
  if (!ac) return; const t = ac.currentTime; const o = out(null, 0);
  click(t, 2500, 0.4, o); const g = ac.createGain(); env(g, t + 0.08, 0.001, 0.12, 0.2); osc('sine', 3300, t + 0.08, 0.25, g); g.connect(o);
}
export function throwWhoosh() {
  if (!ac) return; const t = ac.currentTime; const o = out(null, 0);
  const g = ac.createGain(); env(g, t, 0.06, 0.25, 0.2); const bp = filt('bandpass', 600, 1); bp.frequency.exponentialRampToValueAtTime(1800, t + 0.25); bp.connect(g); g.connect(o); noise(t, 0.3, bp);
}
export function bounce(pos, metal) {
  if (!ac) return; const d = distTo(pos); if (d > 40) return;
  const t = ac.currentTime; const o = out(pos, 0.05, 3);
  const g = ac.createGain(); env(g, t, 0.001, 0.3, 0.1); osc('triangle', metal ? 2600 : rand(500, 800), t, 0.12, g); g.connect(o);
}

// ---------------- Footsteps / body ----------------
export function footstep(pos, isPlayer, sprint, surface = 'mud') {
  if (!ac) return; const d = isPlayer ? 0 : distTo(pos); if (d > 30) return;
  if (!isPlayer && !voice(0.2)) return;
  const t = ac.currentTime; const o = out(isPlayer ? null : pos, 0.03, 2);
  const v = (isPlayer ? 0.32 : 0.5) * (sprint ? 1.3 : 1);
  // boot heel thud
  const g = ac.createGain(); env(g, t, 0.003, v, 0.07);
  const lp = filt('lowpass', 420 + Math.random() * 200); lp.connect(g); g.connect(o); noise(t, 0.1, lp, 0.6);
  // wet squelch
  const g2 = ac.createGain(); env(g2, t + 0.02, 0.01, v * (surface === 'mud' ? 0.6 : 0.25), 0.12);
  const bp = filt('bandpass', 900, 3); bp.frequency.setValueAtTime(1400, t); bp.frequency.exponentialRampToValueAtTime(500, t + 0.14); bp.connect(g2); g2.connect(o);
  noise(t + 0.02, 0.16, bp, 0.8);
  // gear rattle
  if (isPlayer && Math.random() < 0.35) { const g3 = ac.createGain(); env(g3, t + 0.05, 0.001, 0.05, 0.04); const hp = filt('highpass', 5000); hp.connect(g3); g3.connect(o); noise(t + 0.05, 0.06, hp); }
}

export function jumpLand() { footstep(null, true, true); setTimeout(() => footstep(null, true, true), 60); }

// Synthesized human scream (formants)
export function scream(pos, pitch = 1, intensity = 1, moan = false) {
  if (!ac) return; const d = distTo(pos); if (d > 110 || !voice(1.6)) return;
  const t = ac.currentTime; const dur = moan ? rand(0.9, 1.6) : rand(0.5, 1.2);
  const o = out(pos, 0.3, 5);
  const src = ac.createOscillator(); src.type = 'sawtooth';
  const f0 = (moan ? 150 : 330) * pitch * rand(0.9, 1.15);
  src.frequency.setValueAtTime(f0 * 0.8, t);
  src.frequency.linearRampToValueAtTime(f0 * (moan ? 1.1 : 1.35), t + dur * 0.25);
  src.frequency.linearRampToValueAtTime(f0 * (moan ? 0.8 : 0.9), t + dur);
  const vib = ac.createOscillator(); vib.frequency.value = rand(5, 8); const vg = ac.createGain(); vg.gain.value = f0 * 0.04; vib.connect(vg); vg.connect(src.frequency);
  const g = ac.createGain();
  g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.5 * intensity, t + 0.06);
  g.gain.setValueAtTime(0.5 * intensity, t + dur * 0.6); g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  const vowel = moan ? [[400, 6], [800, 8]] : [[rand(750, 900), 6], [rand(1150, 1300), 7], [2600, 9]];
  vowel.forEach(([f, q], i) => { const b = filt('bandpass', f, q); src.connect(b); const bg = ac.createGain(); bg.gain.value = i === 0 ? 1 : 0.6; b.connect(bg); bg.connect(g); });
  const ng = ac.createGain(); ng.gain.value = 0.15; const nb = filt('bandpass', 1800, 1); nb.connect(ng); ng.connect(g); noise(t, dur, nb);
  g.connect(o);
  src.start(t); src.stop(t + dur); vib.start(t); vib.stop(t + dur);
}

export function grunt(pos, pitch = 1) { scream(pos, pitch * 0.7, 0.6, true); }

let heartT = 0;
export function heartbeat(rate) {
  if (!ac || ac.currentTime < heartT) return; const t = ac.currentTime; heartT = t + 60 / rate;
  [0, 0.16].forEach((dt, i) => { const g = ac.createGain(); env(g, t + dt, 0.01, i ? 0.35 : 0.5, 0.12); const s = osc('sine', 55, t + dt, 0.2, g); s.frequency.exponentialRampToValueAtTime(35, t + dt + 0.15); g.connect(master); });
}
let breathT = 0;
export function breath(heavy) {
  if (!ac || ac.currentTime < breathT) return; const t = ac.currentTime; breathT = t + (heavy ? 0.9 : 1.6);
  const g = ac.createGain(); env(g, t, 0.15, heavy ? 0.12 : 0.05, 0.35); const bp = filt('bandpass', 1100, 0.8); bp.connect(g); g.connect(sfxBus); noise(t, 0.6, bp);
}
export function bandage() {
  if (!ac) return; const t = ac.currentTime; const o = out(null, 0);
  for (let i = 0; i < 5; i++) { const tt = t + i * 0.3; const g = ac.createGain(); env(g, tt, 0.05, 0.15, 0.2); const bp = filt('bandpass', 3000, 0.7); bp.connect(g); g.connect(o); noise(tt, 0.3, bp); }
}
export function armorHit() {
  if (!ac) return; const t = ac.currentTime; const o = out(null, 0.1);
  const g = ac.createGain(); env(g, t, 0.001, 0.5, 0.12); osc('square', 420, t, 0.15, g); const lp = filt('lowpass', 2000); g.connect(lp); lp.connect(o);
}

// ---------------- Radio / voice ----------------
export function radioBeep() {
  if (!ac) return; const t = ac.currentTime; const o = out(null, 0.05);
  const g = ac.createGain(); env(g, t, 0.002, 0.12, 0.08); osc('sine', 1400, t, 0.1, g); g.connect(o);
  const g2 = ac.createGain(); env(g2, t + 0.1, 0.002, 0.12, 0.08); osc('sine', 1900, t + 0.1, 0.1, g2); g2.connect(o);
  const g3 = ac.createGain(); env(g3, t + 0.05, 0.02, 0.07, 0.5); const bp = filt('bandpass', 2200, 0.6); bp.connect(g3); g3.connect(o); noise(t + 0.05, 0.6, bp);
}

let speakBusyUntil = 0;
export function speak(text, { pitch = 0.75, rate = 1.08, volume = 1, force = false } = {}) {
  if (!window.speechSynthesis) return false;
  const now = performance.now();
  if (!force && now < speakBusyUntil) return false;
  try {
    speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(text);
    u.lang = 'ru-RU'; if (speechVoice) u.voice = speechVoice;
    u.pitch = pitch; u.rate = rate; u.volume = clamp(volume, 0, 1);
    speechSynthesis.speak(u);
    speakBusyUntil = now + 900 + text.length * 70;
    return true;
  } catch (e) { return false; }
}

// ---------------- Loops: engines, drones ----------------
export function makeLoop(kind) {
  if (!ac) return null;
  const g = ac.createGain(); g.gain.value = 0;
  const p = ac.createPanner(); p.panningModel = 'equalpower'; p.distanceModel = 'inverse'; p.refDistance = kind === 'tank' ? 10 : 6; p.rolloffFactor = 1;
  g.connect(p); p.connect(sfxBus);
  const nodes = [];
  if (kind === 'tank') {
    const o1 = ac.createOscillator(); o1.type = 'sawtooth'; o1.frequency.value = 32;
    const o2 = ac.createOscillator(); o2.type = 'square'; o2.frequency.value = 48;
    const lp = filt('lowpass', 320, 2); o1.connect(lp); const g2 = ac.createGain(); g2.gain.value = 0.35; o2.connect(g2); g2.connect(lp);
    const ns = ac.createBufferSource(); ns.buffer = pinkBuf; ns.loop = true; const nb = filt('bandpass', 180, 1); const ng = ac.createGain(); ng.gain.value = 1.6; ns.connect(nb); nb.connect(ng); ng.connect(lp);
    // track clatter
    const cl = ac.createBufferSource(); cl.buffer = noiseBuf; cl.loop = true; const ch = filt('bandpass', 2200, 2); const cg = ac.createGain(); cg.gain.value = 0; cl.connect(ch); ch.connect(cg); cg.connect(g);
    lp.connect(g); o1.start(); o2.start(); ns.start(); cl.start();
    nodes.push(o1, o2, ns, cl);
    return {
      g, p, nodes, set(pos, rpm, vol, speed) {
        setPos(p, pos); const t = ac.currentTime;
        o1.frequency.setTargetAtTime(28 + rpm * 30, t, 0.15); o2.frequency.setTargetAtTime(42 + rpm * 44, t, 0.15);
        lp.frequency.setTargetAtTime(250 + rpm * 500, t, 0.15);
        g.gain.setTargetAtTime(vol, t, 0.1); cg.gain.setTargetAtTime(Math.min(1, speed / 8) * 0.25, t, 0.1);
      }, stop() { try { nodes.forEach(n => n.stop()); } catch (e) {} g.disconnect(); }
    };
  }
  // drone buzz
  const o1 = ac.createOscillator(); o1.type = 'sawtooth'; o1.frequency.value = 180;
  const o2 = ac.createOscillator(); o2.type = 'sawtooth'; o2.frequency.value = 187;
  const o3 = ac.createOscillator(); o3.type = 'square'; o3.frequency.value = 362;
  const bp = filt('bandpass', 900, 0.7); const g3 = ac.createGain(); g3.gain.value = 0.25;
  o1.connect(bp); o2.connect(bp); o3.connect(g3); g3.connect(bp);
  const lp = filt('lowpass', 3500); bp.connect(lp); lp.connect(g);
  o1.start(); o2.start(); o3.start(); nodes.push(o1, o2, o3);
  return {
    g, p, nodes, set(pos, thr, vol) {
      if (pos) setPos(p, pos); const t = ac.currentTime; const f = 150 + thr * 140;
      o1.frequency.setTargetAtTime(f, t, 0.05); o2.frequency.setTargetAtTime(f * 1.04, t, 0.05); o3.frequency.setTargetAtTime(f * 2.01, t, 0.05);
      g.gain.setTargetAtTime(vol, t, 0.05);
    }, stop() { try { nodes.forEach(n => n.stop()); } catch (e) {} g.disconnect(); }
  };
}
function setPos(p, pos) {
  if (p.positionX) { const t = ac.currentTime; p.positionX.setTargetAtTime(pos.x, t, 0.03); p.positionY.setTargetAtTime(pos.y, t, 0.03); p.positionZ.setTargetAtTime(pos.z, t, 0.03); }
  else p.setPosition(pos.x, pos.y, pos.z);
}

// Non-positional drone buzz for FPV piloting
let fpvLoop = null;
export function fpvBuzz(on, thr = 0.5) {
  if (!ac) return;
  if (on && !fpvLoop) {
    fpvLoop = makeLoop('drone');
    fpvLoop.p.disconnect(); fpvLoop.g.disconnect(); fpvLoop.g.connect(sfxBus);
  }
  if (fpvLoop) fpvLoop.set(null, thr, on ? 0.16 : 0);
  if (!on && fpvLoop) { const l = fpvLoop; fpvLoop = null; setTimeout(() => l.stop(), 300); }
}

// static noise for drone video link
let staticNode = null, staticGain = null;
export function radioStatic(level) {
  if (!ac) return;
  if (!staticNode) {
    staticGain = ac.createGain(); staticGain.gain.value = 0;
    const bp = filt('bandpass', 2500, 0.5); staticNode = ac.createBufferSource(); staticNode.buffer = noiseBuf; staticNode.loop = true;
    staticNode.connect(bp); bp.connect(staticGain); staticGain.connect(master); staticNode.start();
  }
  staticGain.gain.setTargetAtTime(level * 0.12, ac.currentTime, 0.05);
}

// ---------------- Ambience ----------------
let rainGain, windGain;
function startAmbience() {
  // rain: pink noise, high passed
  const r = ac.createBufferSource(); r.buffer = pinkBuf; r.loop = true;
  const hp = filt('highpass', 500); const lp = filt('lowpass', 7000);
  rainGain = ac.createGain(); rainGain.gain.value = 0.32;
  r.connect(hp); hp.connect(lp); lp.connect(rainGain); rainGain.connect(ambBus); r.start();
  // second rain layer: white, higher
  const r2 = ac.createBufferSource(); r2.buffer = noiseBuf; r2.loop = true; const bp2 = filt('bandpass', 5000, 0.4);
  const g2 = ac.createGain(); g2.gain.value = 0.03; r2.connect(bp2); bp2.connect(g2); g2.connect(ambBus); r2.start();
  // wind with LFO
  const w = ac.createBufferSource(); w.buffer = pinkBuf; w.loop = true; w.playbackRate.value = 0.5;
  const wl = filt('lowpass', 400, 4); windGain = ac.createGain(); windGain.gain.value = 0.35;
  const lfo = ac.createOscillator(); lfo.frequency.value = 0.07; const lg = ac.createGain(); lg.gain.value = 250; lfo.connect(lg); lg.connect(wl.frequency); lfo.start();
  w.connect(wl); wl.connect(windGain); windGain.connect(ambBus); w.start();
  // dark ambient drone pad
  const pad = ac.createGain(); pad.gain.value = 0.045; const plp = filt('lowpass', 600); plp.connect(pad); pad.connect(ambBus);
  [55, 82.4, 110.3, 65.4].forEach((f, i) => { const o = ac.createOscillator(); o.type = i % 2 ? 'triangle' : 'sawtooth'; o.frequency.value = f; o.detune.value = rand(-8, 8); o.connect(plp); o.start(); });
  const plfo = ac.createOscillator(); plfo.frequency.value = 0.03; const pg = ac.createGain(); pg.gain.value = 300; plfo.connect(pg); pg.connect(plp.frequency); plfo.start();
  scheduleAmbient();
  scheduleDrops();
}

function drop() {
  const t = ac.currentTime; const g = ac.createGain(); env(g, t, 0.001, rand(0.02, 0.07), 0.04);
  osc('sine', rand(2500, 6000), t, 0.05, g);
  const pan = ac.createStereoPanner ? ac.createStereoPanner() : null;
  if (pan) { pan.pan.value = rand(-1, 1); g.connect(pan); pan.connect(ambBus); } else g.connect(ambBus);
}
function scheduleDrops() {
  setInterval(() => { if (!G.paused) for (let i = 0; i < 3; i++) if (Math.random() < 0.6) drop(); }, 120);
}

function distantBattle() {
  if (G.paused) return;
  const t = ac.currentTime;
  const ang = rand(0, Math.PI * 2), r = rand(250, 600);
  const pos = { x: listenerPos.x + Math.cos(ang) * r, y: 5, z: listenerPos.z + Math.sin(ang) * r };
  const kind = Math.random();
  if (kind < 0.4) explosion(pos, rand(1.2, 2.5));
  else if (kind < 0.8) { // MG burst
    const n = randInt(4, 12), rate = rand(0.07, 0.11), k = pick(['rifle', 'mg', 'rifle']);
    for (let i = 0; i < n; i++) setTimeout(() => shot(k, pos, false), i * rate * 1000);
  } else if (kind < 0.9) { whistle(pos, rand(1.2, 2.2)); setTimeout(() => explosion({ x: pos.x * 0.8, y: 2, z: pos.z * 0.8 }, 2), 1800); }
  else { // artillery salvo
    for (let i = 0; i < 4; i++) setTimeout(() => explosion({ x: pos.x + rand(-40, 40), y: 3, z: pos.z + rand(-40, 40) }, 2.2), i * rand(300, 700));
  }
}
function randInt(a, b) { return Math.floor(rand(a, b + 1)); }
function scheduleAmbient() {
  const next = () => { distantBattle(); setTimeout(next, rand(1500, 6000)); };
  setTimeout(next, 2000);
}

export function thunder(delay = 1) {
  if (!ac) return; const t = ac.currentTime + delay;
  const g = ac.createGain(); g.gain.setValueAtTime(0.0001, t); g.gain.exponentialRampToValueAtTime(0.9, t + 0.08);
  g.gain.exponentialRampToValueAtTime(0.4, t + 0.8); g.gain.exponentialRampToValueAtTime(0.0001, t + 4.5);
  const lp = filt('lowpass', 900); lp.frequency.exponentialRampToValueAtTime(120, t + 4); lp.connect(g);
  const s = ac.createBufferSource(); s.buffer = pinkBuf; s.playbackRate.value = 0.5; s.start(t); s.stop(t + 5); s.connect(lp);
  const w = ac.createGain(); w.gain.value = 0.6; g.connect(w); w.connect(reverbSend); g.connect(ambBus);
  for (let i = 0; i < 5; i++) { const tt = t + rand(0, 1.5); const gg = ac.createGain(); env(gg, tt, 0.005, 0.3, 0.2); const bp = filt('lowpass', 1800); bp.connect(gg); gg.connect(ambBus); noise(tt, 0.3, bp, 0.6); }
}

export function servo(on) {
  // turret traverse whine for player tank / AA
  if (!ac) return;
  if (!audio.servo) {
    const o = ac.createOscillator(); o.type = 'sawtooth'; o.frequency.value = 140; const lp = filt('lowpass', 700); const g = ac.createGain(); g.gain.value = 0;
    o.connect(lp); lp.connect(g); g.connect(sfxBus); o.start(); audio.servo = { o, g };
  }
  audio.servo.g.gain.setTargetAtTime(on ? 0.05 : 0, ac.currentTime, 0.06);
  audio.servo.o.frequency.setTargetAtTime(on ? 170 : 120, ac.currentTime, 0.1);
}

export function setPausedAudio(p) {
  if (!ac) return;
  if (p) ac.suspend(); else ac.resume();
  if (p && window.speechSynthesis) speechSynthesis.cancel();
}
