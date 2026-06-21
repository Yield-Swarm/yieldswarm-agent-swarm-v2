import type { Character, Monster } from '../hooks/useGameSocket';

const CLASS_SKILLS: Record<string, string[]> = {
  runeblade: ['rune_slash', 'blood_sigil', 'shadow_step'],
  voidweaver: ['void_bolt', 'entropy_wave', 'mana_drain'],
  ironwarden: ['shield_bash', 'iron_wall', 'taunt_rune'],
  goldseeker: ['midas_strike', 'vein_sense', 'smelt_rune'],
};

export function CombatHUD({
  character,
  target,
  onSkill,
  runePulse,
}: {
  character: Character;
  target: Monster | null;
  onSkill: (id: string) => void;
  runePulse: number;
}) {
  const skills = CLASS_SKILLS[character.classId] || CLASS_SKILLS.runeblade;
  const hpPct = Math.round((character.hp / character.maxHp) * 100);

  return (
    <div className="combat-hud">
      <div className="combat-hud__stats">
        <div>
          <span className="label">HP</span>
          <div className="bar"><span style={{ width: `${hpPct}%` }} /></div>
          <span>{character.hp}/{character.maxHp}</span>
        </div>
        <div className="rune-balance">
          <span className="label">$RUNE</span>
          <span className={`rune-value ${runePulse > 0 ? 'pulse' : ''}`}>
            {character.runeBalance.toFixed(4)}
          </span>
        </div>
      </div>

      {target ? (
        <div className="combat-hud__target">
          <span>{target.type}</span>
          <div className="bar bar--enemy">
            <span style={{ width: `${(target.hp / target.maxHp) * 100}%` }} />
          </div>
        </div>
      ) : (
        <p className="hint">Tap a red tile to engage · cyan to mine</p>
      )}

      <div className="skill-bar">
        {skills.map((id) => (
          <button
            key={id}
            type="button"
            className="skill-btn"
            onClick={() => onSkill(id)}
            disabled={!target}
          >
            {id.replace(/_/g, ' ')}
          </button>
        ))}
      </div>
    </div>
  );
}
