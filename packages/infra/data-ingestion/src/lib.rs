//! Layers 16–18: Gold API price feed, web crawler, Immunefi bug bounty scraper

use reqwest::Client;
use serde_json::Value;
use std::time::Duration;
use tokio::sync::mpsc;
use tracing::{debug, error};

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct CrawlPayload {
    pub url: String,
    pub data_hash: String,
    pub sample: String,
}

pub struct DataIngestionInfrastructure {
    client: Client,
}

impl DataIngestionInfrastructure {
    pub fn new() -> Self {
        let client = Client::builder()
            .timeout(Duration::from_secs(15))
            .user_agent("YieldSwarmAlphaBot/2.0")
            .build()
            .expect("valid client");
        Self { client }
    }

    /// Layer 16 — Gold spot price (XAU/USD)
    pub async fn fetch_gold_spot_price(&self, api_token: &str) -> Result<f64, String> {
        let url = "https://www.goldapi.io/api/XAU/USD";
        let res = self
            .client
            .get(url)
            .header("x-access-token", api_token)
            .send()
            .await
            .map_err(|e| e.to_string())?;
        let json_data: Value = res.json().await.map_err(|e| e.to_string())?;
        Ok(json_data["price"].as_f64().unwrap_or(0.0))
    }

    /// Layer 17 — Raw crawl target
    pub async fn raw_crawl_target_node(&self, target_url: &str) -> Result<String, String> {
        let res = self
            .client
            .get(target_url)
            .send()
            .await
            .map_err(|e| e.to_string())?;
        res.text().await.map_err(|e| e.to_string())
    }

    /// Layer 17 — Bounded batch crawl into channel
    pub async fn batch_crawl(&self, urls: Vec<String>, tx: mpsc::Sender<CrawlPayload>, limit: usize) {
        let sem = std::sync::Arc::new(tokio::sync::Semaphore::new(limit));
        let mut handles = vec![];

        for url in urls {
            let client = self.client.clone();
            let tx = tx.clone();
            let sem = sem.clone();

            handles.push(tokio::spawn(async move {
                let _permit = sem.acquire().await.unwrap();
                debug!(%url, "crawling");
                match client.get(&url).send().await {
                    Ok(resp) => {
                        if let Ok(body) = resp.text().await {
                            let payload = CrawlPayload {
                                url: url.clone(),
                                data_hash: format!("{:x}", md5::compute(&body)),
                                sample: body.chars().take(1000).collect(),
                            };
                            let _ = tx.send(payload).await;
                        }
                    }
                    Err(e) => error!(%url, error = %e, "crawl failed"),
                }
            }));
        }

        for h in handles {
            let _ = h.await;
        }
    }

    /// Layer 18 — Immunefi active bounties summary
    pub async fn scrape_immunefi_active_bounties(&self) -> Result<Value, String> {
        let url = "https://api.immunefi.com/bounty/summary";
        let res = self
            .client
            .get(url)
            .send()
            .await
            .map_err(|e| e.to_string())?;
        res.json::<Value>().await.map_err(|e| e.to_string())
    }
}

impl Default for DataIngestionInfrastructure {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn infrastructure_constructs() {
        let _ = DataIngestionInfrastructure::new();
    }
}
