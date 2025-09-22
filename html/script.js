// Global state
let availableItems = [];
let currentPlayerData = {
  level: 0,
  title: 'Street Rookie',
  xp: 0,
  nextLevelXP: 100
};
let selectedItem = null;

// Utility functions
function formatPrice(price) {
  return '$' + price.toLocaleString();
}

function updatePlayerInfo(data) {
  currentPlayerData = { ...currentPlayerData, ...data };
  
  document.getElementById('playerLevel').textContent = `Level ${currentPlayerData.level}`;
  document.getElementById('playerTitle').textContent = currentPlayerData.title;
  
  // Update XP bar
  const xpProgress = document.getElementById('xpProgress');
  const xpText = document.getElementById('xpText');
  
  const currentXP = currentPlayerData.xp;
  const nextLevelXP = currentPlayerData.nextLevelXP;
  const prevLevelXP = currentPlayerData.level > 0 ? 
    (currentPlayerData.level === 1 ? 0 : 100) : 0; // Simplified, should use actual level data
  
  const progress = nextLevelXP > currentXP ? 
    ((currentXP - prevLevelXP) / (nextLevelXP - prevLevelXP)) * 100 : 100;
  
  xpProgress.style.width = `${Math.max(0, Math.min(100, progress))}%`;
  xpText.textContent = `${currentXP} / ${nextLevelXP} XP`;
}

function updateItemDescription() {
  const select = document.getElementById('itemSelect');
  const description = document.getElementById('itemDescription');
  
  if (select.value && selectedItem) {
    description.innerHTML = `
      <strong>${selectedItem.label}</strong><br>
      ${selectedItem.description}<br>
      <small>Base Price: ${formatPrice(selectedItem.basePrice)} | Max Amount: ${selectedItem.maxAmount}</small>
    `;
  } else {
    description.innerHTML = '';
  }
}

function updatePriceEstimate() {
  const amount = parseInt(document.getElementById('amount').value) || 0;
  const estimatedPriceEl = document.getElementById('estimatedPrice');
  const riskLevelEl = document.getElementById('riskLevel');
  const amountInfoEl = document.getElementById('amountInfo');
  
  if (selectedItem && amount > 0) {
    // Simple price estimation (server does actual calculation)
    const basePrice = selectedItem.basePrice * amount;
    const estimatedPrice = Math.floor(basePrice * 1.1); // Rough estimate
    
    estimatedPriceEl.textContent = formatPrice(estimatedPrice);
    
    // Update amount info
    if (amount > selectedItem.maxAmount) {
      amountInfoEl.innerHTML = `<span style="color: #ff4444;">⚠️ Maximum allowed: ${selectedItem.maxAmount}</span>`;
      document.getElementById('amount').style.borderColor = '#ff4444';
    } else {
      amountInfoEl.innerHTML = `<span style="color: #00ff88;">✓ Valid amount</span>`;
      document.getElementById('amount').style.borderColor = '#00ff88';
    }
    
    // Update risk level based on item and amount
    let riskClass = 'risk-low';
    let riskText = 'Low';
    
    if (selectedItem.basePrice > 150 || amount > 20) {
      riskClass = 'risk-high';
      riskText = 'High';
    } else if (selectedItem.basePrice > 80 || amount > 10) {
      riskClass = 'risk-medium';
      riskText = 'Medium';
    }
    
    riskLevelEl.className = riskClass;
    riskLevelEl.textContent = riskText;
  } else {
    estimatedPriceEl.textContent = '$0';
    amountInfoEl.innerHTML = '';
    riskLevelEl.className = 'risk-low';
    riskLevelEl.textContent = 'Low';
  }
}

function showStatus(message, type = 'info') {
  const status = document.getElementById('status');
  status.textContent = message;
  status.className = `status ${type}`;
  
  setTimeout(() => {
    status.className = 'status';
    status.textContent = '';
  }, 5000);
}

function populateItemSelect() {
  const select = document.getElementById('itemSelect');
  select.innerHTML = '<option value="">Choose an item...</option>';
  
  availableItems.forEach(item => {
    const option = document.createElement('option');
    option.value = item.name;
    option.textContent = `${item.label} (${formatPrice(item.basePrice)})`;
    select.appendChild(option);
  });
}

// Event listeners
window.addEventListener('message', (event) => {
  const data = event.data;
  
  if (data.action === 'open') {
    document.getElementById('app').classList.remove('hidden');
    
    // Update player info
    if (data.playerLevel !== undefined) {
      updatePlayerInfo({
        level: data.playerLevel,
        title: data.playerTitle,
        xp: data.playerXP,
        nextLevelXP: data.nextLevelXP
      });
    }
    
    // Request available items
    fetch(`https://${GetParentResourceName()}/getAvailableItems`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    }).then(resp => resp.json()).then(data => {
      availableItems = data.items || [];
      populateItemSelect();
    }).catch(err => {
      console.error('Failed to get available items:', err);
      showStatus('Failed to load available items', 'error');
    });
    
  } else if (data.action === 'close') {
    document.getElementById('app').classList.add('hidden');
  }
});

document.getElementById('closeBtn').addEventListener('click', () => {
  fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' });
});

document.getElementById('itemSelect').addEventListener('change', (e) => {
  const itemName = e.target.value;
  selectedItem = availableItems.find(item => item.name === itemName) || null;
  
  // Reset amount to 1 when changing items
  document.getElementById('amount').value = 1;
  
  updateItemDescription();
  updatePriceEstimate();
  
  // Update max attribute on amount input
  if (selectedItem) {
    document.getElementById('amount').max = selectedItem.maxAmount;
  }
});

document.getElementById('amount').addEventListener('input', updatePriceEstimate);

document.getElementById('decreaseBtn').addEventListener('click', () => {
  const amountInput = document.getElementById('amount');
  const currentValue = parseInt(amountInput.value) || 1;
  if (currentValue > 1) {
    amountInput.value = currentValue - 1;
    updatePriceEstimate();
  }
});

document.getElementById('increaseBtn').addEventListener('click', () => {
  const amountInput = document.getElementById('amount');
  const currentValue = parseInt(amountInput.value) || 1;
  const maxAmount = selectedItem ? selectedItem.maxAmount : 100;
  
  if (currentValue < maxAmount) {
    amountInput.value = currentValue + 1;
    updatePriceEstimate();
  }
});

document.getElementById('sellBtn').addEventListener('click', () => {
  if (!selectedItem) {
    showStatus('Please select an item to sell', 'error');
    return;
  }
  
  const amount = parseInt(document.getElementById('amount').value);
  
  if (!amount || amount <= 0) {
    showStatus('Please enter a valid amount', 'error');
    return;
  }
  
  if (amount > selectedItem.maxAmount) {
    showStatus(`Maximum amount for ${selectedItem.label} is ${selectedItem.maxAmount}`, 'error');
    return;
  }
  
  // Disable sell button during transaction
  const sellBtn = document.getElementById('sellBtn');
  sellBtn.disabled = true;
  sellBtn.textContent = '💸 Processing...';
  
  showStatus('Negotiating with buyer...', 'info');
  
  const payload = { 
    item: selectedItem.name, 
    amount: amount, 
    coords: { x: 0, y: 0, z: 0 } 
  };
  
  fetch(`https://${GetParentResourceName()}/requestSell`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload)
  }).then(resp => resp.json()).then(data => {
    if (data.success) {
      const price = data.resp.price || 0;
      const xpGained = data.resp.xpGained || 0;
      
      showStatus(`Deal successful! Earned ${formatPrice(price)} (+${xpGained} XP)`, 'success');
      
      // Update player stats if provided
      if (data.resp.xp !== undefined) {
        updatePlayerInfo({ xp: data.resp.xp });
      }
      
      // Reset form
      document.getElementById('itemSelect').value = '';
      document.getElementById('amount').value = 1;
      selectedItem = null;
      updateItemDescription();
      updatePriceEstimate();
      
    } else {
      const reason = data.reason || (data.resp && data.resp.reason) || 'unknown';
      let friendlyMessage = 'Deal failed';
      
      switch (reason) {
        case 'no_token':
          friendlyMessage = 'No active session - request a new one';
          break;
        case 'no_buyer':
          friendlyMessage = 'No buyer found - find someone to sell to';
          break;
        case 'invalid_item':
          friendlyMessage = 'Invalid item selected';
          break;
        case 'invalid_amount':
          friendlyMessage = 'Invalid amount specified';
          break;
        case 'not_enough':
          friendlyMessage = 'You don\'t have enough of this item';
          break;
        case 'level_too_low':
          friendlyMessage = 'Your level is too low for this item';
          break;
        case 'deal_failed':
          friendlyMessage = 'Buyer rejected the deal';
          break;
        case 'rate_limit':
          friendlyMessage = 'Selling too fast - slow down';
          break;
        case 'cooldown':
          friendlyMessage = 'Wait before making another deal';
          break;
        default:
          friendlyMessage = `Deal failed: ${reason}`;
      }
      
      showStatus(friendlyMessage, 'error');
    }
  }).catch(err => {
    showStatus('Connection error - try again', 'error');
    console.error('Sell request failed:', err);
  }).finally(() => {
    // Re-enable sell button
    sellBtn.disabled = false;
    sellBtn.textContent = '💰 Make Deal';
  });
});

// POST handlers for NUI communication
window.addEventListener('DOMContentLoaded', () => {
  fetch(`https://${GetParentResourceName()}/ready`, { method: 'POST' });
});

// Utility function for resource name
function GetParentResourceName() {
  return window.location.hostname || 'bldr-drugs';
}
