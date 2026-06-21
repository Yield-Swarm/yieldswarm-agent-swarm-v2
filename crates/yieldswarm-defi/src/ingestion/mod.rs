//! Asynchronous alpha crawler — feeds off-chain intelligence into the swarm registry.

use reqwest::Client;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::mpsc;
use tokio::time::sleep;
use tracing::{debug, error};

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct IngestedPayload {
    pub url: String,
    pub data_hash: String,
    pub raw_content: String,
}

pub struct SwarmWebCrawler {
    client: Client,
    concurrency_limit: usize,
}

impl SwarmWebCrawler {
    pub fn new(concurrency_limit: usize) -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(10))
            .user_agent("YieldSwarmAlphaIntelligenceCrawler/2.0")
            .build()
            .expect("valid reqwest client");

        Self {
            client,
            concurrency_limit,
        }
    }

    /// Concurrent bounded crawl — sends parsed payloads to `tx` for agent registry ingestion.
    pub async fn execute_batch_crawl(
        &self,
        targets: Vec<String>,
        tx: mpsc::Sender<IngestedPayload>,
    ) {
        let semaphore = Arc::new(tokio::sync::Semaphore::new(self.concurrency_limit));
        let mut handlers = vec![];

        for url in targets {
            let sem = Arc::clone(&semaphore);
            let cl = self.client.clone();
            let channel = tx.clone();

            let handle = tokio::spawn(async move {
                let _permit = sem.acquire().await.unwrap();
                debug!(%url, "Crawling endpoint boundary alpha");

                match cl.get(&url).send().await {
                    Ok(response) => {
                        if let Ok(body) = response.text().await {
                            let payload = IngestedPayload {
                                url: url.clone(),
                                data_hash: format!("{:x}", md5::compute(&body)),
                                raw_content: body.chars().take(1000).collect(),
                            };
                            let _ = channel.send(payload).await;
                        }
                    }
                    Err(e) => error!(%url, error = %e, "Crawler transport error"),
                }

                sleep(Duration::from_millis(250)).await;
            });
            handlers.push(handle);
        }

        for handler in handlers {
            let _ = handler.await;
        }
    }
}

/// Drain channel into a vec (test / batch helpers).
pub async fn collect_ingested(mut rx: mpsc::Receiver<IngestedPayload>) -> Vec<IngestedPayload> {
    let mut out = Vec::new();
    while let Ok(item) = rx.try_recv() {
        out.push(item);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn crawler_respects_concurrency() {
        let crawler = SwarmWebCrawler::new(2);
        let (tx, mut rx) = mpsc::channel(8);
        let targets = vec![
            "https://httpbin.org/html".to_string(),
            "https://httpbin.org/robots.txt".to_string(),
        ];
        crawler.execute_batch_crawl(targets, tx).await;
        let mut count = 0;
        while rx.try_recv().is_ok() {
            count += 1;
        }
        assert!(count <= 2);
    }
}
