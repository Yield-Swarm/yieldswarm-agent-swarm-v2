import crypto from 'node:crypto';

const TILE = Object.freeze({
  WALL: '#',
  FLOOR: '.',
  SPAWN: 'S',
  EXIT: 'E',
  MONSTER: 'M',
  NODE: 'N',
});

/**
 * Procedural dungeon — seeded PRNG for reproducible floors.
 */
export function generateDungeon(seed, floor = 1) {
  const width = 11 + (floor % 3) * 2;
  const height = 9 + (floor % 2) * 2;
  const rng = seededRng(String(seed) + ':' + floor);
  const grid = Array.from({ length: height }, () => Array(width).fill(TILE.WALL));

  carveRooms(grid, rng, 4 + floor);
  const spawn = placeTile(grid, TILE.SPAWN, rng);
  const exit = placeTile(grid, TILE.EXIT, rng);
  const monsters = [];
  const nodes = [];
  const monsterCount = 3 + floor * 2;

  for (let i = 0; i < monsterCount; i += 1) {
    const pos = placeTile(grid, TILE.MONSTER, rng);
    if (pos) {
      monsters.push(makeMonster(pos, floor, rng));
      grid[pos.y][pos.x] = TILE.FLOOR;
    }
  }

  for (let i = 0; i < 2 + floor; i += 1) {
    const pos = placeTile(grid, TILE.NODE, rng);
    if (pos) {
      nodes.push({ id: `node_${floor}_${i}`, ...pos, ore: 'runic_gold', richness: 1 + rng() * floor });
      grid[pos.y][pos.x] = TILE.FLOOR;
    }
  }

  if (spawn) grid[spawn.y][spawn.x] = TILE.SPAWN;
  if (exit) grid[exit.y][exit.x] = TILE.EXIT;

  return {
    seed,
    floor,
    width,
    height,
    grid,
    spawn,
    exit,
    monsters,
    nodes,
    cleared: false,
  };
}

function makeMonster(pos, floor, rng) {
  const types = ['shade', 'golem', 'wraith', 'cryptlord'];
  const type = types[Math.floor(rng() * types.length)];
  const hp = 30 + floor * 15 + Math.floor(rng() * 20);
  return {
    id: `mob_${pos.x}_${pos.y}_${floor}`,
    type,
    x: pos.x,
    y: pos.y,
    hp,
    maxHp: hp,
    power: 6 + floor * 2,
    runeDrop: 0.5 + floor * 0.3 + rng() * 2,
  };
}

function seededRng(seed) {
  let h = crypto.createHash('sha256').update(seed).digest();
  let i = 0;
  return () => {
    if (i >= h.length - 4) {
      h = crypto.createHash('sha256').update(h).digest();
      i = 0;
    }
    const n = h.readUInt32BE(i);
    i += 4;
    return n / 0xffffffff;
  };
}

function carveRooms(grid, rng, roomCount) {
  const h = grid.length;
  const w = grid[0].length;
  for (let r = 0; r < roomCount; r += 1) {
    const rw = 3 + Math.floor(rng() * 4);
    const rh = 3 + Math.floor(rng() * 3);
    const x = 1 + Math.floor(rng() * Math.max(1, w - rw - 2));
    const y = 1 + Math.floor(rng() * Math.max(1, h - rh - 2));
    for (let dy = 0; dy < rh; dy += 1) {
      for (let dx = 0; dx < rw; dx += 1) {
        grid[y + dy][x + dx] = TILE.FLOOR;
      }
    }
  }
}

function placeTile(grid, tile, rng) {
  const floors = [];
  for (let y = 0; y < grid.length; y += 1) {
    for (let x = 0; x < grid[y].length; x += 1) {
      if (grid[y][x] === TILE.FLOOR) floors.push({ x, y });
    }
  }
  if (!floors.length) return null;
  return floors[Math.floor(rng() * floors.length)];
}

export { TILE };
