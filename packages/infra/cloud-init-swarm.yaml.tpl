#cloud-config
write_files:
  - path: /etc/yieldswarm/swarm.env
    permissions: "0640"
    content: |
      AGENT_COUNT_TOTAL=${agent_count_total}
      CRON_SHARD_COUNT=${cron_shard_count}
      AGENTS_PER_SHARD=${agents_per_shard}
