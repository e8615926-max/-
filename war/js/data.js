// Weapons, characters and shop catalogue
export const WEAPONS = {
  pm: { id: 'pm', name: 'ПМ', kind: 'pistol', vm: 'pm', dmg: 30, rpm: 360, auto: false, mag: 8, reserve: 48, spread: 0.006, hip: 0.03, recoil: 0.035, range: 80, reload: 1.4, sound: 'pistol', zoom: 1.2, ai: 1.0 },
  ak: { id: 'ak', name: 'АК-74М', kind: 'rifle', vm: 'ak', dmg: 34, rpm: 620, auto: true, mag: 30, reserve: 180, spread: 0.004, hip: 0.035, recoil: 0.026, range: 320, reload: 2.3, sound: 'rifle', zoom: 1.45, ai: 1.0 },
  smg: { id: 'smg', name: 'ПП-19 «Бизон»', kind: 'smg', vm: 'smg', dmg: 24, rpm: 760, auto: true, mag: 64, reserve: 192, spread: 0.008, hip: 0.03, recoil: 0.017, range: 130, reload: 2.6, sound: 'smg', zoom: 1.3, ai: 1.3 },
  shotgun: { id: 'shotgun', name: 'Сайга-12', kind: 'shotgun', vm: 'shotgun', dmg: 17, pellets: 9, rpm: 230, auto: false, mag: 8, reserve: 48, spread: 0.05, hip: 0.07, recoil: 0.075, range: 50, reload: 3.2, sound: 'shotgun', zoom: 1.2, ai: 2 },
  svd: { id: 'svd', name: 'СВД', kind: 'sniper', vm: 'svd', dmg: 115, rpm: 110, auto: false, mag: 10, reserve: 50, spread: 0.0005, hip: 0.06, recoil: 0.085, range: 650, reload: 2.8, sound: 'sniper', zoom: 4.5, scope: true, ai: 0.5 },
  pkm: { id: 'pkm', name: 'ПКМ', kind: 'mg', vm: 'pkm', dmg: 37, rpm: 650, auto: true, mag: 100, reserve: 300, spread: 0.008, hip: 0.045, recoil: 0.034, range: 380, reload: 4.6, sound: 'mg', zoom: 1.35, ai: 1.5 },
  rpg: { id: 'rpg', name: 'РПГ-7', kind: 'rocket', vm: 'rpg', dmg: 0, rpm: 30, auto: false, mag: 1, reserve: 4, spread: 0.003, hip: 0.02, recoil: 0.12, range: 300, reload: 3.2, sound: 'shotgun', zoom: 1.4, projectile: 'rocket', ai: 1 },
};

export const CHARACTERS = [
  { id: 'assault', name: 'Гром', title: 'Штурмовик', icon: '⚔️', desc: '+20% здоровья, 4 гранаты, АК-74М', hp: 120, weapons: ['ak', 'pm'], grenades: 4, bandages: 2, medkits: 0, fpv: 1, bombers: 0, perks: {} },
  { id: 'medic', name: 'Ангел', title: 'Медик', icon: '✚', desc: 'Лечит и поднимает раненых союзников. Регенерация, 6 бинтов', hp: 100, weapons: ['smg', 'pm'], grenades: 2, bandages: 6, medkits: 2, fpv: 1, bombers: 0, perks: { medic: true, regen: 1.5 } },
  { id: 'sniper', name: 'Тень', title: 'Снайпер', icon: '🎯', desc: 'СВД с оптикой, отдача и качание −50%, тихие шаги', hp: 90, weapons: ['svd', 'pm'], grenades: 1, bandages: 2, medkits: 0, fpv: 1, bombers: 0, perks: { steady: 0.5, quiet: true } },
  { id: 'gunner', name: 'Бык', title: 'Пулемётчик', icon: '🔥', desc: 'ПКМ, бронежилет и каска с самого начала', hp: 110, weapons: ['pkm', 'pm'], grenades: 2, bandages: 2, medkits: 0, fpv: 1, bombers: 0, vest: 1, helmet: true, perks: {} },
  { id: 'operator', name: 'Сокол', title: 'Оператор БПЛА', icon: '🛸', desc: '3 FPV + бомбер, батарея +60%, дальняя связь', hp: 100, weapons: ['ak', 'pm'], grenades: 2, bandages: 2, medkits: 0, fpv: 3, bombers: 1, perks: { droneBat: 1.6, droneRange: 1.6 } },
  { id: 'tanker', name: 'Броня', title: 'Танкист', icon: '🛡️', desc: 'Перезарядка танка −35%, ремонт техники, РПГ', hp: 100, weapons: ['smg', 'pm', 'rpg'], grenades: 2, bandages: 2, medkits: 0, fpv: 1, bombers: 0, perks: { tankReload: 0.65, repair: true } },
];

export const SHOP = [
  { cat: 'Оружие', id: 'w_ak', name: 'АК-74М', desc: 'Надёжный автомат, 30 патр.', price: 250, weapon: 'ak' },
  { cat: 'Оружие', id: 'w_smg', name: 'ПП-19 «Бизон»', desc: 'Скорострельный, магазин 64', price: 450, weapon: 'smg' },
  { cat: 'Оружие', id: 'w_shotgun', name: 'Сайга-12', desc: 'Дробовик для ближнего боя', price: 500, weapon: 'shotgun' },
  { cat: 'Оружие', id: 'w_svd', name: 'СВД', desc: 'Снайперская винтовка, оптика ×4.5', price: 900, weapon: 'svd' },
  { cat: 'Оружие', id: 'w_rpg', name: 'РПГ-7', desc: 'Противотанковый гранатомёт', price: 1000, weapon: 'rpg' },
  { cat: 'Оружие', id: 'w_pkm', name: 'ПКМ', desc: 'Пулемёт, лента на 100', price: 1200, weapon: 'pkm' },
  { cat: 'Броня', id: 'helmet', name: 'Каска 6Б47', desc: '−50% урона в голову, шанс рикошета', price: 300 },
  { cat: 'Броня', id: 'vest', name: 'Бронежилет 6Б45', desc: '−40% урона в корпус, 120 ед.', price: 600 },
  { cat: 'Броня', id: 'heavy', name: 'Штурмовой костюм', desc: '−60% корпус и конечности, 220 ед., тяжёлый', price: 1300 },
  { cat: 'Снаряжение', id: 'ammo', name: 'Боекомплект', desc: 'Пополнить патроны всего оружия', price: 100 },
  { cat: 'Снаряжение', id: 'grenades', name: 'Гранаты РГД-5 ×2', desc: 'Осколочные гранаты', price: 150 },
  { cat: 'Снаряжение', id: 'bandages', name: 'Бинты ×3', desc: 'Останавливают кровотечение', price: 100 },
  { cat: 'Снаряжение', id: 'medkit', name: 'Аптечка', desc: '+60 HP и лечение ран', price: 250 },
  { cat: 'Снаряжение', id: 'rockets', name: 'Выстрелы РПГ ×2', desc: 'Для РПГ-7', price: 200 },
  { cat: 'Дроны', id: 'fpv', name: 'FPV-дрон камикадзе', desc: 'Быстрый, взрывается при ударе', price: 300 },
  { cat: 'Дроны', id: 'bomber', name: 'Дрон-бомбер', desc: '4 сброса, зависание, медленный', price: 450 },
];

export const COINS = { kill: 100, head: 50, tank: 500, drone: 150, aa: 300, revive: 75, heal: 25, capture: 200, assist: 40 };

export const LINES = {
  advance: ['Вперёд, братья! За мной!', 'Не отставать! Держать строй!', 'Пошли, пошли, пошли!', 'Давим их! Вперёд!', 'Штурмуем точку! Не останавливаться!'],
  hold: ['Держать позиции!', 'Ни шагу назад!', 'Окопаться и держать оборону!', 'Стоим насмерть, мужики!'],
  fire: ['Огонь! Огонь по готовности!', 'Прижать их огнём!', 'Огонь по пехоте!', 'Подавить пулемётчика!'],
  tank: ['Танк противника! Гранатомётчики, к бою!', 'Броня на фланге! РПГ сюда!'],
  drone: ['Дрон в воздухе! ПВО, работать!', 'Воздух! Все в укрытие!', 'Птичка над нами! Сбить её!'],
  captured: ['Точка наша! Отличная работа!', 'Флаг взят! Закрепиться!'],
  lost: ['Точку потеряли! Отбить немедленно!', 'Нас выбили! Перегруппироваться!'],
  reinforce: ['Подкрепление прибыло! Выдвигаемся!', 'Свежие силы на подходе! Вперёд!'],
  morale: ['Мы их сломаем! Держитесь, братцы!', 'Ещё немного! Они бегут!', 'Помните, ради чего мы здесь!', 'Боевой дух высок! Вперёд!'],
  medic: ['Медик! Нужен медик!', 'Санитар! Я ранен!', 'Помогите! Меня зацепило!', 'А-а-а! Медик!'],
  grenade: ['Граната!', 'Ложись! Граната!'],
  enemy: ['Вперёд! Вперёд!', 'Атакуем!', 'Огонь! Огонь!', 'Не отступать!', 'Окружай их!'],
};
