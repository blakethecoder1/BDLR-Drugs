window.addEventListener('message', (event) => {
  const d = event.data
  if (d.action === 'open') {
    document.getElementById('app').classList.remove('hidden')
  } else if (d.action === 'close') {
    document.getElementById('app').classList.add('hidden')
  }
})

document.getElementById('closeBtn').addEventListener('click', () => {
  fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' })
})

document.getElementById('sellBtn').addEventListener('click', () => {
  const item = document.getElementById('item').value
  const amount = parseInt(document.getElementById('amount').value, 10)
  const payload = { item: item, amount: amount, coords: {} }
  fetch(`https://${GetParentResourceName()}/requestSell`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload)
  }).then(resp => resp.json()).then(data => {
    if (data.success) {
      document.getElementById('status').innerText = 'Sold for $' + data.resp.price
    } else {
      document.getElementById('status').innerText = 'Failed: ' + (data.resp and data.resp.reason ? data.resp.reason : 'unknown')
    }
  }).catch(err => {
    document.getElementById('status').innerText = 'Request error'
  })
})

// POST handlers to communicate with client.lua

window.addEventListener('DOMContentLoaded', () => {
  fetch(`https://${GetParentResourceName()}/ready`, { method: 'POST' })
})

// Callbacks for NUI

// Using the NUI callbacks system

function postToClient(event, data) {
  fetch(`https://${GetParentResourceName()}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data)
  })
}

// NUI endpoints

window.addEventListener('message', (e) => {})
