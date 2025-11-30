// Global state
let availableItems = [];
let currentPlayerData = {
  level: 0,
  title: 'Street Rookie',
  xp: 0,
  nextLevelXP: 100
};
let selectedItem = null;

// Apply custom UI colors from config
function applyCustomColors(colors) {
  if (!colors) return;
  
  const root = document.documentElement;
  if (colors.primary) root.style.setProperty('--color-primary', colors.primary);
  if (colors.secondary) root.style.setProperty('--color-secondary', colors.secondary);
  if (colors.background) root.style.setProperty('--color-background', colors.background);
  if (colors.backgroundAlt) root.style.setProperty('--color-background-alt', colors.backgroundAlt);
  if (colors.text) root.style.setProperty('--color-text', colors.text);
  if (colors.textMuted) root.style.setProperty('--color-text-muted', colors.textMuted);
  if (colors.success) root.style.setProperty('--color-success', colors.success);
  if (colors.warning) root.style.setProperty('--color-warning', colors.warning);
  if (colors.error) root.style.setProperty('--color-error', colors.error);
  
  console.log('Applied custom UI colors:', colors);
}

// Apply custom gradients
function applyCustomGradients(gradients) {
  if (!gradients) return;
  
  const root = document.documentElement;
  if (gradients.panel) root.style.setProperty('--gradient-panel', gradients.panel);
  if (gradients.header) root.style.setProperty('--gradient-header', gradients.header);
  if (gradients.xpBar) root.style.setProperty('--gradient-xp', gradients.xpBar);
  
  console.log('Applied custom gradients:', gradients);
}

// Get the correct resource name for NUI communication
function getResourceName() {
  // Remove the cfx-nui- prefix if it exists
  let resourceName = GetParentResourceName();
  if (resourceName.startsWith('cfx-nui-')) {
    resourceName = resourceName.substring(8); // Remove 'cfx-nui-' prefix
  }
  return resourceName;
}

// Fetch available items with retry mechanism
function fetchAvailableItems(retryCount = 0) {
  const maxRetries = 3;
  const retryDelay = 1000; // 1 second
  const resourceName = getResourceName();
  
  console.log('Fetching items from resource:', resourceName, 'attempt:', retryCount + 1);
  
  // Test NUI communication first
  if (retryCount === 0) {
    fetch(`https://${resourceName}/test`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    }).then(resp => resp.json()).then(data => {
      console.log('NUI test successful:', data);
    }).catch(err => {
      console.error('NUI test failed:', err);
    });
  }
  
  fetch(`https://${resourceName}/getAvailableItems`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  }).then(resp => {
    console.log('Response status:', resp.status, 'OK:', resp.ok);
    if (!resp.ok) {
      throw new Error(`HTTP error! status: ${resp.status}`);
    }
    return resp.text().then(text => {
      console.log('Raw response:', text);
      try {
        return text ? JSON.parse(text) : {};
      } catch (e) {
        console.error('Invalid JSON response:', text);
        throw new Error('Invalid JSON response from server');
      }
    });
  }).then(data => {
    console.log('Parsed data:', data);
    availableItems = data.items || [];
    populateItemSelect();
    console.log('Successfully loaded', availableItems.length, 'available items');
  }).catch(err => {
    console.error('Failed to get available items (attempt', retryCount + 1, '):', err);
    
    if (retryCount < maxRetries) {
      console.log('Retrying in', retryDelay, 'ms...');
      setTimeout(() => {
        fetchAvailableItems(retryCount + 1);
      }, retryDelay);
    } else {
      showStatus('Failed to load available items after ' + (maxRetries + 1) + ' attempts', 'error');
      // Add some fallback items for testing
      console.log('Adding fallback items for testing');
      availableItems = [
        { name: 'weed', label: 'Weed', basePrice: 50, maxAmount: 50, description: 'High quality street weed' }
      ];
      populateItemSelect();
    }
  });
}

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
    console.log('UI opened, adding mouse event debugging');
    document.getElementById('app').classList.remove('hidden');
    resetAutoCloseTimer(); // Start auto-close timer
    
    // Apply custom colors if provided
    if (data.colors) {
      applyCustomColors(data.colors);
    }
    if (data.gradients) {
      applyCustomGradients(data.gradients);
    }
    
    // Add debugging for mouse interaction
    document.addEventListener('click', function(e) {
      console.log('Click detected on:', e.target.tagName, e.target.id, e.target.className);
    }, { once: false });
    
    document.addEventListener('mousedown', function(e) {
      console.log('Mouse down detected on:', e.target.tagName, e.target.id);
    }, { once: false });
    
    // Update player info
    if (data.playerLevel !== undefined) {
      updatePlayerInfo({
        level: data.playerLevel,
        title: data.playerTitle,
        xp: data.playerXP,
        nextLevelXP: data.nextLevelXP
      });
    }
    
    // Request available items with retry mechanism (delayed start)
    console.log('UI opened, requesting available items...');
    
    // Force request player stats first
    fetch(`https://${getResourceName()}/requestPlayerStats`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    }).catch(err => console.log('Player stats request sent'));
    
    setTimeout(() => {
      fetchAvailableItems();
      
      // Test UI element accessibility
      const sellBtn = document.getElementById('sellBtn');
      const closeBtn = document.getElementById('closeBtn');
      const itemSelect = document.getElementById('itemSelect');
      
      console.log('UI elements check:');
      console.log('Sell button:', sellBtn ? 'Found' : 'Missing', sellBtn?.style.display);
      console.log('Close button:', closeBtn ? 'Found' : 'Missing', closeBtn?.style.display);
      console.log('Item select:', itemSelect ? 'Found' : 'Missing', itemSelect?.style.display);
      
      // Test if elements are clickable
      if (sellBtn) {
        console.log('Sell button clickable:', !sellBtn.disabled, 'Style:', getComputedStyle(sellBtn).pointerEvents);
      }
      if (closeBtn) {
        console.log('Close button clickable:', !closeBtn.disabled, 'Style:', getComputedStyle(closeBtn).pointerEvents);
      }
      
    }, 500); // Wait 500ms to ensure resource is ready
    
  } else if (data.action === 'close') {
    if (autoCloseTimer) clearTimeout(autoCloseTimer); // Clear timer
    closeUI();
  }
});

document.getElementById('closeBtn').addEventListener('click', () => {
  console.log('Close button clicked');
  closeUI();
});

// Add click debugging to sell button
document.getElementById('sellBtn').addEventListener('click', () => {
  console.log('Sell button clicked');
  // Rest of sell logic follows...
});

// Add ESC key support and improved close functionality
let isClosing = false; // Prevent multiple close calls

function closeUI() {
  if (isClosing) return; // Prevent double-closing
  isClosing = true;
  
  console.log('Closing UI...');
  document.getElementById('app').classList.add('hidden');
  
  // Send close request to Lua (only once)
  fetch(`https://${getResourceName()}/close`, { 
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  }).then(() => {
    console.log('Close callback sent successfully');
  }).catch(err => {
    console.error('Close callback error:', err);
  }).finally(() => {
    // Reset the closing flag after a delay
    setTimeout(() => {
      isClosing = false;
    }, 500);
  });
}

// Auto-close failsafe - close UI after 5 minutes if still open
let autoCloseTimer = null;
function resetAutoCloseTimer() {
  if (autoCloseTimer) clearTimeout(autoCloseTimer);
  autoCloseTimer = setTimeout(() => {
    console.log('Auto-closing UI due to timeout');
    closeUI();
  }, 300000); // 5 minutes
}

// Listen for ESC key
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !document.getElementById('app').classList.contains('hidden')) {
    closeUI();
  }
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
  console.log('Sell button clicked - starting validation');
  
  if (!selectedItem) {
    console.log('No item selected');
    showStatus('Please select an item to sell', 'error');
    return;
  }
  
  console.log('Selected item:', selectedItem);
  
  const amount = parseInt(document.getElementById('amount').value);
  
  if (!amount || amount <= 0) {
    console.log('Invalid amount:', amount);
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
  
  fetch(`https://${getResourceName()}/requestSell`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload)
  }).then(resp => {
    console.log('Sell response status:', resp.status, 'OK:', resp.ok);
    if (!resp.ok) {
      throw new Error(`HTTP error! status: ${resp.status}`);
    }
    return resp.text().then(text => {
      console.log('Sell response text:', text);
      try {
        return text ? JSON.parse(text) : { success: false, reason: 'empty_response' };
      } catch (e) {
        console.error('Invalid JSON response:', text);
        throw new Error('Invalid JSON response from server');
      }
    });
  }).then(data => {
    console.log('Parsed sell response:', data);
    
    if (data.success) {
      const price = data.moneyEarned || 0;
      const xpGained = data.xpGained || 0;
      
      showStatus(`Deal successful! Earned ${formatPrice(price)} (+${xpGained} XP)`, 'success');
      
      // Update player stats if provided
      if (data.playerXP !== undefined) {
        updatePlayerInfo({ xp: data.playerXP });
      }
      
      // Reset form
      document.getElementById('itemSelect').value = '';
      document.getElementById('amount').value = 1;
      selectedItem = null;
      updateItemDescription();
      updatePriceEstimate();
      
    } else {
      const reason = data.reason || 'unknown';
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
        case 'empty_response':
          friendlyMessage = 'Server communication error';
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
  fetch(`https://${getResourceName()}/ready`, { method: 'POST' });
  initializeThemeModal();
});

// Utility function for resource name
function GetParentResourceName() {
  return window.location.hostname || 'bldr-drugs';
}

// Theme Modal Functionality
function initializeThemeModal() {
  const themeBtn = document.getElementById('themeBtn');
  const themeModal = document.getElementById('themeModal');
  const closeThemeBtn = document.getElementById('closeThemeBtn');
  const applyThemeBtn = document.getElementById('applyThemeBtn');
  const resetThemeBtn = document.getElementById('resetThemeBtn');
  
  // Color input elements
  const colorInputs = {
    primary: document.getElementById('colorPrimary'),
    success: document.getElementById('colorSuccess'),
    warning: document.getElementById('colorWarning'),
    error: document.getElementById('colorError'),
    text: document.getElementById('colorText'),
    textMuted: document.getElementById('colorTextMuted')
  };
  
  const textInputs = {
    primary: document.getElementById('colorPrimaryText'),
    success: document.getElementById('colorSuccessText'),
    warning: document.getElementById('colorWarningText'),
    error: document.getElementById('colorErrorText'),
    text: document.getElementById('colorTextText'),
    textMuted: document.getElementById('colorTextMutedText')
  };
  
  // Preset themes
  const presets = {
    default: {
      primary: '#00ff88',
      success: '#00ff88',
      warning: '#ffaa00',
      error: '#ff4444',
      text: '#ffffff',
      textMuted: '#a0a0a0'
    },
    blue: {
      primary: '#00aaff',
      success: '#00ff88',
      warning: '#ffaa00',
      error: '#ff4444',
      text: '#ffffff',
      textMuted: '#a0a0a0'
    },
    purple: {
      primary: '#aa00ff',
      success: '#00ff88',
      warning: '#ffaa00',
      error: '#ff4444',
      text: '#ffffff',
      textMuted: '#a0a0a0'
    },
    red: {
      primary: '#ff0044',
      success: '#00ff88',
      warning: '#ffaa00',
      error: '#ff4444',
      text: '#ffffff',
      textMuted: '#a0a0a0'
    },
    gold: {
      primary: '#ffaa00',
      success: '#00ff88',
      warning: '#ffaa00',
      error: '#ff4444',
      text: '#ffffff',
      textMuted: '#a0a0a0'
    },
    cyan: {
      primary: '#00ffff',
      success: '#00ff88',
      warning: '#ffaa00',
      error: '#ff4444',
      text: '#ffffff',
      textMuted: '#a0a0a0'
    }
  };
  
  // Get current colors from CSS variables
  function getCurrentColors() {
    const root = document.documentElement;
    const computedStyle = getComputedStyle(root);
    return {
      primary: computedStyle.getPropertyValue('--color-primary').trim(),
      success: computedStyle.getPropertyValue('--color-success').trim(),
      warning: computedStyle.getPropertyValue('--color-warning').trim(),
      error: computedStyle.getPropertyValue('--color-error').trim(),
      text: computedStyle.getPropertyValue('--color-text').trim(),
      textMuted: computedStyle.getPropertyValue('--color-text-muted').trim()
    };
  }
  
  // Load current colors into inputs
  function loadCurrentColors() {
    const colors = getCurrentColors();
    Object.keys(colors).forEach(key => {
      if (colorInputs[key]) {
        colorInputs[key].value = colors[key];
        if (textInputs[key]) {
          textInputs[key].value = colors[key].toUpperCase();
        }
      }
    });
  }
  
  // Sync color picker with text input
  Object.keys(colorInputs).forEach(key => {
    colorInputs[key].addEventListener('input', (e) => {
      const value = e.target.value;
      textInputs[key].value = value.toUpperCase();
      applyColorPreview(key, value);
    });
    
    textInputs[key].addEventListener('input', (e) => {
      let value = e.target.value;
      if (!value.startsWith('#')) value = '#' + value;
      if (/^#[0-9A-Fa-f]{6}$/.test(value)) {
        colorInputs[key].value = value;
        applyColorPreview(key, value);
      }
    });
  });
  
  // Apply color preview in real-time
  function applyColorPreview(key, value) {
    const root = document.documentElement;
    root.style.setProperty(`--color-${key === 'textMuted' ? 'text-muted' : key}`, value);
  }
  
  // Open modal
  themeBtn.addEventListener('click', () => {
    themeModal.classList.remove('hidden');
    loadCurrentColors();
  });
  
  // Close modal
  closeThemeBtn.addEventListener('click', () => {
    themeModal.classList.add('hidden');
  });
  
  // Close modal when clicking outside
  themeModal.addEventListener('click', (e) => {
    if (e.target === themeModal) {
      themeModal.classList.add('hidden');
    }
  });
  
  // Apply preset theme
  document.querySelectorAll('.preset-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const presetName = btn.dataset.preset;
      const preset = presets[presetName];
      if (preset) {
        Object.keys(preset).forEach(key => {
          if (colorInputs[key]) {
            colorInputs[key].value = preset[key];
            textInputs[key].value = preset[key].toUpperCase();
            applyColorPreview(key, preset[key]);
          }
        });
      }
    });
  });
  
  // Reset to default colors
  resetThemeBtn.addEventListener('click', () => {
    const defaultColors = presets.default;
    Object.keys(defaultColors).forEach(key => {
      if (colorInputs[key]) {
        colorInputs[key].value = defaultColors[key];
        textInputs[key].value = defaultColors[key].toUpperCase();
        applyColorPreview(key, defaultColors[key]);
      }
    });
  });
  
  // Apply and save colors
  applyThemeBtn.addEventListener('click', () => {
    const colors = {
      primary: colorInputs.primary.value,
      success: colorInputs.success.value,
      warning: colorInputs.warning.value,
      error: colorInputs.error.value,
      text: colorInputs.text.value,
      textMuted: colorInputs.textMuted.value
    };
    
    // Send to Lua backend to save
    fetch(`https://${getResourceName()}/saveColors`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ colors: colors })
    }).then(resp => resp.json()).then(data => {
      if (data.success) {
        console.log('Colors saved successfully');
        themeModal.classList.add('hidden');
      } else {
        console.error('Failed to save colors:', data.message);
      }
    }).catch(err => {
      console.error('Error saving colors:', err);
    });
  });
}
