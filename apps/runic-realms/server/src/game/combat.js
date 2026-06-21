import { SKILL_TABLE } from './classes.js';
import { harvestCompute } from './compute.js';
import { submitComputeJob } from './swarmBridge.js';

export function resolveSkillAttack(attacker, target, skillId, floor = 1) {
  const skill = SKILL_TABLE[skillId];
  if (!skill) {
    return { ok: false, error: 'unknown_skill' };
  }

  const cd = attacker.cooldowns[skillId] || 0;
  if (cd > 0) {
    return { ok: false, error: 'on_cooldown', remaining: cd };
  }

  const damage = Math.max(1, Math.floor(skill.damage + attacker.power * 0.5 - (target.armor || 0)));
  target.hp = Math.max(0, target.hp - damage);
  if (skill.shield) attacker.shield = (attacker.shield || 0) + skill.shield;
  if (skill.heal) attacker.hp = Math.min(attacker.maxHp, attacker.hp + skill.heal);

  attacker.cooldowns[skillId] = skill.cooldown;

  const compute = harvestCompute('combat_skill', {
    skillId,
    computeWeight: skill.computeWeight,
    floor,
    level: attacker.level,
    targetType: target.type || 'monster',
  });

  return {
    ok: true,
    skillId,
    damage,
    targetHp: target.hp,
    killed: target.hp <= 0,
    compute,
  };
}

export function monsterCounterAttack(monster, player) {
  const damage = Math.max(1, monster.power - Math.floor((player.shield || 0) / 3));
  player.hp = Math.max(0, player.hp - damage);
  player.shield = Math.max(0, (player.shield || 0) - 5);
  return { damage, playerHp: player.hp };
}

export async function grantLoot(player, monster, floor) {
  const rarityRoll = Math.random();
  const rarity = rarityRoll > 0.95 ? 'legendary' : rarityRoll > 0.8 ? 'epic' : rarityRoll > 0.5 ? 'rare' : 'common';
  const item = {
    id: `item_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    name: `${rarity} ${monster.type} relic`,
    rarity,
    slot: 'trinket',
    onChainId: null,
    utility: { power: 1 + floor * 0.2 },
  };

  const compute = harvestCompute('loot_drop', { floor, level: player.level, rarity, computeWeight: 2.5 });
  player.runeBalance = Math.round((player.runeBalance + compute.runeEarned + monster.runeDrop) * 10000) / 10000;
  player.xp += 10 + floor * 5;
  player.inventory.push(item);

  if (player.xp >= player.level * 100) {
    player.level += 1;
    player.maxHp += 10;
    player.hp = player.maxHp;
    player.power += 2;
    player.xp = 0;
  }

  const bridge = await submitComputeJob(compute.job, player.id, { telegramId: player.telegramId });
  return { item, compute, bridge, runeEarned: compute.runeEarned + monster.runeDrop };
}

export function tickCooldowns(player) {
  for (const key of Object.keys(player.cooldowns)) {
    if (player.cooldowns[key] > 0) player.cooldowns[key] -= 1;
  }
}
