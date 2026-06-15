import { createOdysseusHandoff, getCurrentSession } from "../shared/auth.js";
import { resolveConfig } from "../shared/config.js";

const config = resolveConfig();
const iframe = document.querySelector("[data-odysseus-frame]");
const openEmbedded = document.querySelector("[data-open-embedded]");
const openExternal = document.querySelector("[data-open-external]");
const statusNode = document.querySelector("[data-portal-status]");
const sessionNode = document.querySelector("[data-session-summary]");

function setStatus(message, state = "info") {
  statusNode.textContent = message;
  statusNode.dataset.state = state;
}

function summarizeSession(session) {
  if (!session) {
    return "No local session found. Odysseus handoff will rely on shared cookies.";
  }

  const user = session.email ?? session.userId ?? session.subject ?? "authenticated user";
  const tenant = session.tenantId ? ` in tenant ${session.tenantId}` : "";
  return `Signed in as ${user}${tenant}.`;
}

async function openOdysseus(target = "/", mode = "embedded") {
  setStatus("Creating Odysseus SSO handoff...", "loading");

  try {
    const session = await getCurrentSession({ config });
    sessionNode.textContent = summarizeSession(session);
    const url = await createOdysseusHandoff({
      targetPath: target,
      session,
      config
    });

    if (mode === "external") {
      window.open(url, "_blank", "noopener,noreferrer");
      setStatus("Opened Odysseus in a linked workspace.", "ready");
      return;
    }

    iframe.src = url;
    iframe.hidden = false;
    iframe.focus();
    setStatus("Embedded Odysseus workspace is loading.", "ready");
  } catch (error) {
    setStatus(error.message, "error");
  }
}

async function bootstrapSession() {
  const session = await getCurrentSession({ config });
  sessionNode.textContent = summarizeSession(session);
  openExternal.href = config.odysseusWorkspaceUrl;
}

openEmbedded?.addEventListener("click", () => openOdysseus("/research", "embedded"));
openExternal?.addEventListener("click", (event) => {
  event.preventDefault();
  openOdysseus("/research", "external");
});

window.addEventListener("message", (event) => {
  if (!iframe.src || new URL(iframe.src, window.location.href).origin !== event.origin) {
    return;
  }

  if (event.data?.type === "odysseus:ready") {
    setStatus("Odysseus workspace connected.", "ready");
  }
});

bootstrapSession();
