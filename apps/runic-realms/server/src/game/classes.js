/** Fantasy class archetypes — WoW-style rotations */
export const CLASSES = Object.freeze({
  runeblade: {
    id: 'runeblade',
    name: 'Runeblade',
    role: 'melee',
    hp: 120,
    power: 14,
    skills: ['rune_slash', 'blood_sigil', 'shadow_step'],
  },
  voidweaver: {
    id: 'voidweaver',
    name: 'Voidweaver',
    role: 'caster',
    hp: 90,
    power: 18,
    skills: ['void_bolt', 'entropy_wave', 'mana_drain'],
  },
  ironwarden: {
    id: 'ironwarden',
    name: 'Ironwarden',
    role: 'tank',
    hp: 160,
    power: 10,
    skills: ['shield_bash', 'iron_wall', 'taunt_rune'],
  },
  goldseeker: {
    id: 'goldseeker',
    name: 'Goldseeker',
    role: 'gatherer',
    hp: 100,
    power: 12,
    skills: ['midas_strike', 'vein_sense', 'smelt_rune'],
  },
});

export const SKILL_TABLE = Object.freeze({
  rune_slash: { damage: 22, cooldown: 0, computeWeight: 1.2 },
  blood_sigil: { damage: 35, cooldown: 3, computeWeight: 1.8 },
  shadow_step: { damage: 15, cooldown: 2, computeWeight: 1.0 },
  void_bolt: { damage: 28, cooldown: 0, computeWeight: 1.4 },
  entropy_wave: { damage: 40, cooldown: 4, computeWeight: 2.2 },
  mana_drain: { damage: 12, heal: 8, cooldown: 2, computeWeight: 1.1 },
  shield_bash: { damage: 18, cooldown: 1, computeWeight: 1.0 },
  iron_wall: { damage: 0, shield: 25, cooldown: 5, computeWeight: 0.8 },
  taunt_rune: { damage: 8, cooldown: 3, computeWeight: 0.9 },
  midas_strike: { damage: 20, cooldown: 0, computeWeight: 2.0 },
  vein_sense: { damage: 5, mineBonus: 1.5, cooldown: 2, computeWeight: 1.6 },
  smelt_rune: { damage: 30, cooldown: 4, computeWeight: 2.4 },
});

export function createCharacter(classId, telegramId, displayName) {
  const cls = CLASSES[classId] || CLASSES.runeblade;
  return {
    id: `char_${telegramId}`,
    telegramId,
    displayName: displayName || 'Wanderer',
    classId: cls.id,
    level: 1,
    xp: 0,
    hp: cls.hp,
    maxHp: cls.hp,
    power: cls.power,
    runeBalance: 0,
    inventory: [],
    cooldowns: {},
    dungeonFloor: 1,
  };
}
