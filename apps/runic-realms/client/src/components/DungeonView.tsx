import type { Dungeon } from '../hooks/useGameSocket';

const TILE_COLORS: Record<string, string> = {
  '#': '#1a1020',
  '.': '#2a1838',
  S: '#3ddc97',
  E: '#ffb020',
  M: '#ff4757',
  N: '#4ecdc4',
};

export function DungeonView({
  dungeon,
  onEngage,
  onMine,
}: {
  dungeon: Dungeon;
  onEngage: (id: string) => void;
  onMine: (id: string) => void;
}) {
  const monsterAt = (x: number, y: number) =>
    dungeon.monsters.find((m) => m.x === x && m.y === y && m.hp > 0);
  const nodeAt = (x: number, y: number) =>
    dungeon.nodes.find((n) => n.x === x && n.y === y);

  return (
    <div className="dungeon">
      <div className="dungeon__header">
        <span>Floor {dungeon.floor}</span>
        {dungeon.cleared ? <span className="cleared">CLEARED</span> : null}
      </div>
      <div
        className="dungeon__grid"
        style={{
          gridTemplateColumns: `repeat(${dungeon.grid[0]?.length || 11}, 1fr)`,
        }}
      >
        {dungeon.grid.map((row, y) =>
          row.map((cell, x) => {
            const mob = monsterAt(x, y);
            const node = nodeAt(x, y);
            const display = mob ? 'M' : node ? 'N' : cell;
            return (
              <button
                key={`${x}-${y}`}
                type="button"
                className="dungeon__tile"
                style={{ background: TILE_COLORS[display] || TILE_COLORS['.'] }}
                onClick={() => {
                  if (mob) onEngage(mob.id);
                  else if (node) onMine(node.id);
                }}
                aria-label={mob ? `fight ${mob.type}` : node ? 'mine' : 'tile'}
              />
            );
          }),
        )}
      </div>
    </div>
  );
}
