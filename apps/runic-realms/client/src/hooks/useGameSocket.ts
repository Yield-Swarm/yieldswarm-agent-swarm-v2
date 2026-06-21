import { useCallback, useEffect, useRef, useState } from 'react';

export type Monster = {
  id: string;
  type: string;
  hp: number;
  maxHp: number;
  x: number;
  y: number;
};

export type Character = {
  id: string;
  displayName: string;
  classId: string;
  level: number;
  hp: number;
  maxHp: number;
  power: number;
  runeBalance: number;
  inventory: { id: string; name: string; rarity: string }[];
  cooldowns: Record<string, number>;
};

export type Dungeon = {
  floor: number;
  grid: string[][];
  monsters: Monster[];
  nodes: { id: string; x: number; y: number; ore: string }[];
  cleared: boolean;
};

type GameEvent = {
  type: string;
  [key: string]: unknown;
};

const WS_BASE = (import.meta.env.VITE_RUNIC_WS as string)
  || `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}`;

export function useGameSocket(telegramId: string, classId: string, name: string) {
  const wsRef = useRef<WebSocket | null>(null);
  const [connected, setConnected] = useState(false);
  const [character, setCharacter] = useState<Character | null>(null);
  const [dungeon, setDungeon] = useState<Dungeon | null>(null);
  const [combatTarget, setCombatTarget] = useState<Monster | null>(null);
  const [lastLoot, setLastLoot] = useState<string | null>(null);
  const [runePulse, setRunePulse] = useState(0);
  const [log, setLog] = useState<string[]>([]);

  const pushLog = useCallback((line: string) => {
    setLog((prev) => [line, ...prev].slice(0, 8));
  }, []);

  const connect = useCallback(() => {
    if (wsRef.current?.readyState === WebSocket.OPEN) return;
    const q = new URLSearchParams({ tg: telegramId, class: classId, name });
    const ws = new WebSocket(`${WS_BASE}/ws?${q}`);
    wsRef.current = ws;

    ws.onopen = () => setConnected(true);
    ws.onclose = () => setConnected(false);
    ws.onmessage = (ev) => {
      const msg = JSON.parse(ev.data as string) as GameEvent;
      switch (msg.type) {
        case 'welcome':
          setCharacter(msg.character as Character);
          setDungeon(msg.dungeon as Dungeon);
          pushLog('Entered the Runic Realms');
          break;
        case 'dungeon':
          setDungeon(msg.dungeon as Dungeon);
          setCombatTarget(null);
          break;
        case 'combat_start':
          setCombatTarget(msg.target as Monster);
          pushLog(`Engaged ${(msg.target as Monster).type}`);
          break;
        case 'combat_hit':
          setCharacter(msg.player as Character);
          setCombatTarget(msg.target as Monster);
          setRunePulse((msg.runeEarned as number) || 0);
          pushLog(`${msg.skillId} → ${msg.damage} dmg · +${msg.runeEarned} RUNE`);
          break;
        case 'loot':
          setCharacter(msg.player as Character);
          setLastLoot((msg.item as { name: string })?.name || 'Loot');
          setDungeon((d) => (d ? { ...d, cleared: Boolean(msg.dungeonCleared) } : d));
          pushLog(`Loot: ${(msg.item as { name: string })?.name}`);
          break;
        case 'mined':
          setCharacter(msg.player as Character);
          setRunePulse((msg.runeEarned as number) || 0);
          pushLog(`Mined +${msg.runeEarned} RUNE`);
          break;
        case 'player_down':
          setCharacter(msg.player as Character);
          pushLog('You fell — revived at spawn');
          break;
        default:
          break;
      }
    };
  }, [telegramId, classId, name, pushLog]);

  useEffect(() => {
    connect();
    return () => wsRef.current?.close();
  }, [connect]);

  const send = useCallback((payload: object) => {
    wsRef.current?.send(JSON.stringify(payload));
  }, []);

  return {
    connected,
    character,
    dungeon,
    combatTarget,
    lastLoot,
    runePulse,
    log,
    engage: (monsterId: string) => send({ type: 'engage', monsterId }),
    skill: (skillId: string) => send({ type: 'skill', skillId }),
    mine: (nodeId: string) => send({ type: 'mine', nodeId }),
    nextFloor: () => send({ type: 'next_floor' }),
    rerollDungeon: () => send({ type: 'enter_dungeon' }),
  };
}
