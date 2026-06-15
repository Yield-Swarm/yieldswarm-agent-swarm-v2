# Bootstrap Deity identities into Odysseus ChromaDB memory.

from odysseus_memory import get_memory


COUNCIL_ROLES = [
    ("deity-001", "Kimiclaw", "head_of_consensus_council", "9/14 threshold lead"),
    ("deity-002", "Deity Council Seat 02", "primary_deity", "consensus vote"),
    ("deity-003", "Deity Council Seat 03", "primary_deity", "consensus vote"),
    ("deity-004", "Deity Council Seat 04", "primary_deity", "consensus vote"),
    ("deity-005", "Deity Council Seat 05", "primary_deity", "consensus vote"),
    ("deity-006", "Deity Council Seat 06", "primary_deity", "consensus vote"),
    ("deity-007", "Deity Council Seat 07", "primary_deity", "consensus vote"),
    ("deity-008", "Deity Council Seat 08", "primary_deity", "consensus vote"),
    ("deity-009", "Deity Council Seat 09", "primary_deity", "consensus vote"),
    ("deity-010", "Supporting Council Seat 10", "supporting_deity", "consensus support"),
    ("deity-011", "Supporting Council Seat 11", "supporting_deity", "consensus support"),
    ("deity-012", "Supporting Council Seat 12", "supporting_deity", "consensus support"),
    ("deity-013", "Supporting Council Seat 13", "supporting_deity", "consensus support"),
    ("deity-014", "Supporting Council Seat 14", "supporting_deity", "consensus support"),
]


memory = get_memory()

for council_seat, (deity_id, name, role, authority) in enumerate(COUNCIL_ROLES, start=1):
    memory.upsert_deity_identity(
        deity_id=deity_id,
        name=name,
        role=role,
        authority=authority,
        council_seat=council_seat,
        traits=["kimiclaw", "runic", "governance", "odysseus-memory"],
    )

for deity_number in range(15, 170):
    deity_id = f"deity-{deity_number:03d}"
    memory.upsert_deity_identity(
        deity_id=deity_id,
        name=f"Operational Deity {deity_number:03d}",
        role="operational_deity",
        authority="agent mesh validation and long-term memory stewardship",
        traits=["agent-validation", "mesh-learning", "odysseus-memory"],
    )

print("Bootstrapped 169 Deity identities into Odysseus memory")
