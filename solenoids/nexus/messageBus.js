/**
 * Cross-solenoid messaging bus — in-process pub/sub with optional persistence.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { MESSAGE_TOPICS } from './constants.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const LOG_PATH = process.env.NEXUS_BUS_LOG ||
  path.join(REPO_ROOT, '.run', 'nexus-bus.jsonl');

const MAX_BUFFER = 500;

export class CrossSolenoidBus {
  constructor() {
    /** @type {Map<string, Set<Function>>} */
    this.subscribers = new Map();
    /** @type {object[]} */
    this.buffer = [];
  }

  subscribe(topic, handler) {
    if (!this.subscribers.has(topic)) {
      this.subscribers.set(topic, new Set());
    }
    this.subscribers.get(topic).add(handler);
    return () => this.subscribers.get(topic)?.delete(handler);
  }

  async publish(topic, payload, meta = {}) {
    const envelope = {
      id: `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
      topic,
      sourceSolenoid: meta.sourceSolenoid || 'nexus',
      targetSolenoid: meta.targetSolenoid || null,
      timestamp: new Date().toISOString(),
      payload,
    };

    this.buffer.push(envelope);
    if (this.buffer.length > MAX_BUFFER) {
      this.buffer = this.buffer.slice(-MAX_BUFFER);
    }

    await this._appendLog(envelope);

    const handlers = this.subscribers.get(topic) || new Set();
    const wildcard = this.subscribers.get('*') || new Set();
    for (const fn of [...handlers, ...wildcard]) {
      try {
        fn(envelope);
      } catch {
        // subscriber errors must not block bus
      }
    }

    return envelope;
  }

  async _appendLog(envelope) {
    try {
      await fs.mkdir(path.dirname(LOG_PATH), { recursive: true });
      await fs.appendFile(LOG_PATH, `${JSON.stringify(envelope)}\n`, 'utf8');
    } catch {
      // best-effort persistence
    }
  }

  recent(topic = null, limit = 20) {
    let items = [...this.buffer];
    if (topic) items = items.filter((e) => e.topic === topic);
    return items.slice(-limit);
  }

  topics() {
    return { ...MESSAGE_TOPICS };
  }
}
