# Odysseus Memory Sync Service
# Exposes the peer endpoint used by Akash workers and multi-cloud nodes.

import os

from odysseus_memory import get_memory


memory = get_memory()
host = os.getenv("ODYSSEUS_SYNC_HOST", "0.0.0.0")
port = int(os.getenv("ODYSSEUS_SYNC_PORT", "8097"))

memory.register_agent_mesh()
print(
    "Odysseus sync service active "
    f"node={memory.config.node_id} host={host} port={port}"
)
memory.serve_sync_api(host=host, port=port)
