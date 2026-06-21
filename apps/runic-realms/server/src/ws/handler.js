import crypto from 'node:crypto';
import { WebSocketServer } from 'ws';
import { createCharacter, CLASSES } from './game/classes.js';
import { generateDungeon } from './game/dungeon.js';
import { harvestCompute } from './game/compute.js';
import { submitComputeJob } from './game/swarmBridge.js';
import { registerPlotraDeity, plotraAvatarUrl } from './agents/plotraAgents.js';
import {
  grantLoot,
  monsterCounterAttack,
  resolveSkillAttack,
  tickCooldowns,
} from './game/combat.js';

const sessions = new Map();

export function getSession(playerId) {
  return sessions.get(playerId);
}

export function attachGameWebSocket(server) {
  const wss = new WebSocketServer({ server, path: '/ws' });

  wss.on('connection', (ws, req) => {
    const url = new URL(req.url || '/', 'http://localhost');
    const telegramId = url.searchParams.get('tg') || `guest_${crypto.randomBytes(4).toString('hex')}`;
    const classId = url.searchParams.get('class') || 'runeblade';
    const name = url.searchParams.get('name') || 'Baris';

    let session = sessions.get(telegramId);
    if (!session) {
      const character = createCharacter(classId, telegramId, name);
      const dungeon = generateDungeon(telegramId, 1);
      session = { character, dungeon, combatTarget: null, plotra: null };
      sessions.set(telegramId, session);
      registerPlotraDeity(character).then((plotra) => {
        session.plotra = plotra;
        character.plotraViewUrl = plotraAvatarUrl(plotra);
        character.plotraAgentId = plotra.agent_id;
        send(ws, { type: 'plotra_ready', plotra: { view_url: plotra.view_url, agent_id: plotra.agent_id } });
      }).catch(() => {});
    }

    send(ws, {
      type: 'welcome',
      character: session.character,
      dungeon: publicDungeon(session.dungeon),
      classes: CLASSES,
      plotra: session.plotra ? { view_url: session.plotra.view_url, agent_id: session.plotra.agent_id } : null,
    });

    ws.on('message', (raw) => {
      try {
        const msg = JSON.parse(String(raw));
        handleMessage(ws, telegramId, msg);
      } catch (err) {
        send(ws, { type: 'error', message: err.message });
      }
    });
  });

  return wss;
}

function handleMessage(ws, playerId, msg) {
  const session = sessions.get(playerId);
  if (!session) return;

  switch (msg.type) {
    case 'enter_dungeon':
      session.dungeon = generateDungeon(playerId, session.character.dungeonFloor);
      send(ws, { type: 'dungeon', dungeon: publicDungeon(session.dungeon) });
      break;

    case 'engage':
      engageMonster(ws, session, msg.monsterId);
      break;

    case 'skill':
      castSkill(ws, session, msg.skillId);
      break;

    case 'mine':
      mineNode(ws, session, msg.nodeId);
      break;

    case 'next_floor':
      if (session.dungeon.cleared) {
        session.character.dungeonFloor += 1;
        session.dungeon = generateDungeon(playerId, session.character.dungeonFloor);
        send(ws, { type: 'dungeon', dungeon: publicDungeon(session.dungeon) });
      }
      break;

    default:
      send(ws, { type: 'error', message: 'unknown_message' });
  }
}

function engageMonster(ws, session, monsterId) {
  const mob = session.dungeon.monsters.find((m) => m.id === monsterId && m.hp > 0);
  if (!mob) {
    send(ws, { type: 'error', message: 'monster_not_found' });
    return;
  }
  session.combatTarget = mob;
  send(ws, { type: 'combat_start', target: mob, player: session.character });
}

async function castSkill(ws, session, skillId) {
  const target = session.combatTarget;
  if (!target || target.hp <= 0) {
    send(ws, { type: 'error', message: 'no_target' });
    return;
  }

  tickCooldowns(session.character);
  const result = resolveSkillAttack(
    session.character,
    target,
    skillId,
    session.dungeon.floor,
  );

  if (!result.ok) {
    send(ws, { type: 'combat_fail', ...result });
    return;
  }

  const bridge = await submitComputeJob(result.compute.job, session.character.id, {
    telegramId: playerId,
  });
  session.character.runeBalance = Math.round(
    (session.character.runeBalance + result.compute.runeEarned) * 10000,
  ) / 10000;

  send(ws, {
    type: 'combat_hit',
    skillId,
    damage: result.damage,
    target,
    runeEarned: result.compute.runeEarned,
    proofHash: result.compute.proofHash,
    bridge,
    player: session.character,
  });

  if (result.killed) {
    const loot = await grantLoot(session.character, target, session.dungeon.floor);
    session.dungeon.monsters = session.dungeon.monsters.filter((m) => m.hp > 0);
    session.combatTarget = null;
    if (session.dungeon.monsters.length === 0) session.dungeon.cleared = true;
    send(ws, { type: 'loot', ...loot, player: session.character, dungeonCleared: session.dungeon.cleared });
    return;
  }

  const counter = monsterCounterAttack(target, session.character);
  send(ws, { type: 'combat_counter', ...counter, target });

  if (session.character.hp <= 0) {
    session.character.hp = session.character.maxHp;
    session.combatTarget = null;
    send(ws, { type: 'player_down', player: session.character });
  }
}

async function mineNode(ws, session, nodeId) {
  const node = session.dungeon.nodes.find((n) => n.id === nodeId);
  if (!node) {
    send(ws, { type: 'error', message: 'node_not_found' });
    return;
  }

  const compute = harvestCompute('mine_node', {
    floor: session.dungeon.floor,
    level: session.character.level,
    computeWeight: 1.8 * node.richness,
    ore: node.ore,
  });

  session.character.runeBalance = Math.round(
    (session.character.runeBalance + compute.runeEarned) * 10000,
  ) / 10000;

  const bridge = await submitComputeJob(compute.job, session.character.id, { telegramId: playerId });
  send(ws, {
    type: 'mined',
    node,
    runeEarned: compute.runeEarned,
    proofHash: compute.proofHash,
    bridge,
    player: session.character,
  });
}

function publicDungeon(dungeon) {
  return {
    seed: dungeon.seed,
    floor: dungeon.floor,
    width: dungeon.width,
    height: dungeon.height,
    grid: dungeon.grid,
    spawn: dungeon.spawn,
    exit: dungeon.exit,
    monsters: dungeon.monsters,
    nodes: dungeon.nodes,
    cleared: dungeon.cleared,
  };
}

function send(ws, payload) {
  if (ws.readyState === ws.OPEN) {
    ws.send(JSON.stringify(payload));
  }
}
