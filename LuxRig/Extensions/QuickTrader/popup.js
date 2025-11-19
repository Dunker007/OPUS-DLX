// LuxRig QuickTrader - Browser Extension Logic

document.getElementById('buyBtn').addEventListener('click', () => {
  executeTrade('BUY');
});

document.getElementById('sellBtn').addEventListener('click', () => {
  executeTrade('SELL');
});

function executeTrade(side) {
  const symbol = document.getElementById('symbol').value;
  const amount = document.getElementById('amount').value;
  const status = document.getElementById('status');

  if (!amount || amount <= 0) {
    status.textContent = '❌ Invalid amount';
    status.style.color = '#f00';
    return;
  }

  status.textContent = `⏳ Executing ${side} ${amount} ${symbol}...`;
  status.style.color = '#0ff';

  // Simulate API call
  setTimeout(() => {
    const orderId = 'ORD-' + Math.random().toString(36).substr(2, 9).toUpperCase();
    status.textContent = `✅ ${side} order placed! ID: ${orderId}`;
    status.style.color = '#0f0';

    // Send notification
    chrome.notifications.create({
      type: 'basic',
      iconUrl: 'icons/icon48.png',
      title: 'LuxRig Trade Executed',
      message: `${side} ${amount} ${symbol} - Order ${orderId}`,
      priority: 2
    });

    // Clear form
    document.getElementById('amount').value = '';
  }, 1000);
}

// Price updates
function updatePrices() {
  // In production, fetch from API
  console.log('Updating prices...');
}

// Update every 30 seconds
setInterval(updatePrices, 30000);
updatePrices();
