use serde_json::Value;

pub fn post_json(url: &str, headers: &[(&str, &str)], body: Value) -> Result<Value, String> {
    let payload = serde_json::to_string(&body).map_err(|e| e.to_string())?;
    let mut request = minreq::post(url).with_body(payload);
    for (k, v) in headers {
        request = request.with_header(*k, *v);
    }
    if !headers.iter().any(|(k, _)| *k == "Content-Type") {
        request = request.with_header("Content-Type", "application/json");
    }
    let response = request.send().map_err(|e| e.to_string())?;
    if response.status_code < 200 || response.status_code >= 300 {
        return Err(format!(
            "HTTP {}: {}",
            response.status_code,
            response.as_str().unwrap_or("")
        ));
    }
    serde_json::from_str(response.as_str().unwrap_or("{}")).map_err(|e| e.to_string())
}
