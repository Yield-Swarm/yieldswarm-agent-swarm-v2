import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { generateDungeon } from './dungeon.js';
import { harvestCompute, sanscriptOp } from './compute.js';
import { resolveSkillAttack } from './combat.js';
import { createCharacter } from './classes.js';

describe('dungeon generation', () => {
  it('produces deterministic dungeons for same seed', () => {
    const a = generateDungeon('baris', 1);
    const b = generateDungeon('baris', 1);
    assert.equal(a.width, b.width);
    assert.equal(a.monsters.length, b.monsters.length);
  });

  it('scales monsters with floor', () => {
    const d = generateDungeon('test', 5);
    assert.ok(d.monsters.length >= 5);
  });
});

describe('proof-of-compute', () => {
  it('emits sanscript YSLR primitive', () => {
    const op = sanscriptOp('mine', { floor: 2 });
    assert.match(op, /^YSLR::COMPUTE::mine::[a-f0-9]{16}$/);
  });

  it('awards RUNE for actions', () => {
    const { runeEarned, proofHash } = harvestCompute('kill', { computeWeight: 2, floor: 3, level: 2 });
    assert.ok(runeEarned > 0);
    assert.equal(proofHash.length, 64);
  });
});

describe('combat', () => {
  it('skill reduces monster hp', () => {
    const player = createCharacter('runeblade', '1', 'Test');
    const mob = { type: 'shade', hp: 50, maxHp: 50, power: 5 };
    const result = resolveSkillAttack(player, mob, 'rune_slash', 1);
    assert.equal(result.ok, true);
    assert.ok(mob.hp < 50);
  });
});
