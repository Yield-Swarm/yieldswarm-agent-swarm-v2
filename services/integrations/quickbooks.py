"""QuickBooks Online payroll sync stub."""

from __future__ import annotations

import os
from typing import Any, Dict


def quickbooks_status() -> Dict[str, Any]:
    client_id = os.environ.get("QUICKBOOKS_CLIENT_ID", "")
    realm = os.environ.get("QUICKBOOKS_REALM_ID", "")
    return {
        "configured": bool(client_id and realm),
        "client_id_set": bool(client_id),
        "realm_id_set": bool(realm),
        "sync_mode": os.environ.get("QUICKBOOKS_SYNC_MODE", "manual"),
        "payroll_export_path": os.environ.get("QUICKBOOKS_EXPORT_DIR", ".run/payroll"),
    }
