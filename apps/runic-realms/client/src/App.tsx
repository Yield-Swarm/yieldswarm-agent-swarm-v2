import { useEffect, useState } from 'react';
import { useTelegram } from './hooks/useTelegram';
import { useGameSocket } from './hooks/useGameSocket';
import { DungeonView } from './components/DungeonView';
import { CombatHUD } from './components/CombatHUD';

const CLASSES = [
  { id: 'runeblade', name: 'Runeblade', desc: 'Melee burst' },
  { id: 'voidweaver', name: 'Voidweaver', desc: 'Arcane DPS' },
  { id: 'ironwarden', name: 'Ironwarden', desc: 'Tank control' },
  { id: 'goldseeker', name: 'Goldseeker', desc: 'Midas miner' },
];

export function App() {
  const tg = useTelegram();
  const [classId, setClassId] = useState('runeblade');
  const [started, setStarted] = useState(false);

  useEffect(() => {
    tg.ready();
  }, [tg]);

  const game = useGameSocket(tg.telegramId, classId, tg.displayName);

  if (!started) {
    return (
      <div className="screen screen--title">
        <h1>Runic Realms</h1>
        <p className="tagline">Kill. Mine. Earn $RUNE. Power the Swarm.</p>
        <div className="class-grid">
          {CLASSES.map((c) => (
            <button
              key={c.id}
              type="button"
              className={`class-card ${classId === c.id ? 'active' : ''}`}
              onClick={() => { setClassId(c.id); tg.haptic(); }}
            >
              <strong>{c.name}</strong>
              <span>{c.desc}</span>
            </button>
          ))}
        </div>
        <button
          type="button"
          className="primary-btn"
          onClick={() => { setStarted(true); tg.haptic(); }}
        >
          Enter the Realm
        </button>
        <footer className="compute-note">
          Every action generates proof-of-compute for Runic Chain
        </footer>
      </div>
    );
  }

  if (!game.character || !game.dungeon) {
    return <div className="screen">Connecting to Runic Chain…</div>;
  }

  return (
    <div className="screen screen--game">
      <header className="top-bar">
        <div>
          <strong>{game.character.displayName}</strong>
          <span>Lv.{game.character.level} {game.character.classId}</span>
        </div>
        <span className={`conn ${game.connected ? 'live' : ''}`}>
          {game.connected ? '● LIVE' : '○ …'}
        </span>
      </header>

      <DungeonView
        dungeon={game.dungeon}
        onEngage={(id) => { game.engage(id); tg.haptic(); }}
        onMine={(id) => { game.mine(id); tg.haptic(); }}
      />

      <CombatHUD
        character={game.character}
        target={game.combatTarget}
        onSkill={(id) => { game.skill(id); tg.haptic(); }}
        runePulse={game.runePulse}
      />

      {game.lastLoot ? <div className="loot-toast">{game.lastLoot}</div> : null}

      {game.dungeon.cleared ? (
        <button type="button" className="primary-btn" onClick={game.nextFloor}>
          Descend — Floor {game.dungeon.floor + 1}
        </button>
      ) : null}

      <div className="event-log">
        {game.log.map((line, i) => (
          <div key={i} className="log-line">{line}</div>
        ))}
      </div>
    </div>
  );
}
