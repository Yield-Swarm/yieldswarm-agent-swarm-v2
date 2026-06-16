/**
 * Re-exports axios-backed HTTP client (preferred).
 * Legacy fetch-based helpers remain available via httpClient.
 */
export { fetchJson, rpc, UpstreamError, requestJson } from './httpClient.js';
