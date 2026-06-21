"""Single Pane of Glass — unified prompt registry and status."""

from services.single_pane.registry import PromptRegistry, get_prompt_status

__all__ = ["PromptRegistry", "get_prompt_status"]
