async function refresh() {
  const data = await chrome.storage.local.get([
    'status', 'lotteryTickets', 'points', 'myReferralCode', 'nodeId',
  ]);
  document.getElementById('status').textContent = data.status || 'offline';
  document.getElementById('status').className = data.status === 'online' ? 'status-online' : 'status-offline';
  document.getElementById('tickets').textContent = data.lotteryTickets ?? 0;
  document.getElementById('points').textContent = data.points ?? 0;
  document.getElementById('referral').textContent = data.myReferralCode || '—';
}

document.getElementById('sync').addEventListener('click', () => {
  chrome.runtime.sendMessage({ type: 'heartbeat-now' }, () => refresh());
});

document.getElementById('share').addEventListener('click', () => {
  chrome.runtime.sendMessage({ type: 'record-action', action: 'share' }, () => refresh());
});

refresh();
