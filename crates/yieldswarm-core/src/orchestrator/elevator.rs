//! 14-elevator parallel processing pipeline — Prompt 36.

use crate::SwarmMessage;
use futures::future::join_all;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tracing::debug;

pub const ELEVATOR_COUNT: usize = 14;

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ElevatorLaneResult {
    pub lane: u8,
    pub message_id: String,
    pub ok: bool,
    pub detail: String,
}

/// Schedules messages across 14 parallel elevator lanes.
pub struct ElevatorScheduler;

impl ElevatorScheduler {
    /// Fan-out one message per lane (14 parallel tokio tasks).
    pub async fn dispatch_parallel<F, Fut>(
        message: SwarmMessage,
        handler: Arc<F>,
    ) -> Vec<ElevatorLaneResult>
    where
        F: Fn(u8, SwarmMessage) -> Fut + Send + Sync + 'static,
        Fut: std::future::Future<Output = String> + Send + 'static,
    {
        let tasks: Vec<_> = (0..ELEVATOR_COUNT as u8)
            .map(|lane| {
                let msg = message.clone();
                let handler = Arc::clone(&handler);
                tokio::spawn(async move {
                    debug!("Elevator lane {} processing {}", lane, msg.id);
                    let detail = handler(lane, msg.clone()).await;
                    ElevatorLaneResult {
                        lane,
                        message_id: msg.id,
                        ok: true,
                        detail,
                    }
                })
            })
            .collect();

        join_all(tasks)
            .await
            .into_iter()
            .filter_map(|r| r.ok())
            .collect()
    }

    /// Route a single message to one lane (hash of message id mod 14).
    pub fn select_lane(message: &SwarmMessage) -> u8 {
        message
            .elevator_lane
            .unwrap_or_else(|| simple_hash(&message.id) % ELEVATOR_COUNT as u8)
    }
}

fn simple_hash(s: &str) -> u8 {
    s.bytes().fold(0u8, |acc, b| acc.wrapping_add(b))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::SwarmMessage;

    #[test]
    fn lane_in_range() {
        let msg = SwarmMessage::broadcast("src", "payload");
        let lane = ElevatorScheduler::select_lane(&msg);
        assert!(lane < ELEVATOR_COUNT as u8);
    }
}
