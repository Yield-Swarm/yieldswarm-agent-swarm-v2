//! YieldSwarm Core binary — boots Apollo Nexus runtime.

use tracing_subscriber::EnvFilter;
use yieldswarm_core::orchestrator::ApolloNexus;
use yieldswarm_core::registry::AgentProfile;
use yieldswarm_core::SwarmMessage;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(EnvFilter::from_default_env().add_directive("yieldswarm_core=info".parse().unwrap()))
        .init();

    let (nexus, rx) = ApolloNexus::bootstrap(1024);
    let handle = nexus.spawn_runtime(rx);

    // Seed demo agents
    let reg = nexus.registry();
    reg.register_agent(AgentProfile::new(
        "broadcast-001",
        vec!["broadcast_listener".into()],
    ));

    nexus
        .dispatch(SwarmMessage::broadcast("apollo-nexus", "genesis ping"))
        .await
        .expect("dispatch");

    let _ = nexus
        .dispatch_yslr_frame("YSLR lane=3 route=helix payload={\"boot\":true}")
        .await;

    tracing::info!(
        "yieldswarm-core running — agents={}",
        reg.count()
    );

    // Keep runtime alive briefly for demo; production runs until signal.
    tokio::time::sleep(std::time::Duration::from_secs(1)).await;
    handle.abort();
}
