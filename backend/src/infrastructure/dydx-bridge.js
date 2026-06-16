/**
 * dYdX v4 execution bridge — indexer reads for autonomous trading agents.
 */

import { requestJson } from '../lib/httpClient.js';

export class DydxExecutionBridge {
  /**
   * @param {string} indexerUrl - dYdX v4 indexer base (e.g. https://indexer.dydx.trade/v4)
   * @param {string} subaccountId - Agent subaccount / address pointer
   */
  constructor(indexerUrl = 'https://indexer.dydx.trade/v4', subaccountId = '') {
    this.indexerUrl = indexerUrl.replace(/\/$/, '');
    this.subaccountId = subaccountId;
    this.wsEndpoint = `${this.indexerUrl.replace('https://', 'wss://')}/ws`;
  }

  /**
   * Fetch live perpetual market statistics.
   * @param {string} marketTicker - e.g. "BTC-USD"
   */
  async getMarketPrice(marketTicker) {
    const url = `${this.indexerUrl}/perpetualMarkets?ticker=${encodeURIComponent(marketTicker)}`;
    const response = await requestJson({ method: 'GET', url });
    const marketData = response.data?.markets?.[marketTicker];
    if (!marketData) {
      throw new Error(`Market not found: ${marketTicker}`);
    }
    return {
      ticker: marketTicker,
      oraclePrice: Number.parseFloat(marketData.oraclePrice),
      nextFundingRate: Number.parseFloat(marketData.nextFundingRate),
      status: marketData.status,
      live: true,
      source: 'dydx-indexer',
    };
  }

  /**
   * Query active positions for the configured subaccount.
   */
  async fetchActivePositions() {
    if (!this.subaccountId) {
      return { positions: [], live: false, source: 'dydx-indexer', error: 'subaccountId not set' };
    }
    const url = `${this.indexerUrl}/addresses/${encodeURIComponent(this.subaccountId)}/positions`;
    const response = await requestJson({ method: 'GET', url });
    return {
      positions: response.data?.positions || [],
      live: true,
      source: 'dydx-indexer',
      subaccountId: this.subaccountId,
    };
  }

  /**
   * Health ping — verifies indexer reachability.
   */
  async ping() {
    try {
      await this.getMarketPrice('BTC-USD');
      return { live: true, indexerUrl: this.indexerUrl };
    } catch (err) {
      return { live: false, indexerUrl: this.indexerUrl, error: err.message };
    }
  }
}

export default DydxExecutionBridge;
