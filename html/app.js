window.addEventListener('message', function(event) {
    const data = event.data;
    if (data.action == 'open') {
        document.getElementById('app').classList.remove('hidden');
        window.currentToken = data.token
    }
});

document.getElementById('sell').addEventListener('click', function() {
    const item = document.getElementById('item').value
    const amount = document.getElementById('amount').value
    fetch(`https://${GetParentResourceName()}/sell`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ item: item, amount: amount })
    }).then(res => res.json()).then(resp => {
        if (resp && resp.success) {
            document.getElementById('app').classList.add('hidden')
        }
    })
});

document.getElementById('close').addEventListener('click', function() {
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' })
    document.getElementById('app').classList.add('hidden')
});

// NUI callbacks from Lua
window.addEventListener('message', function(event) {
    const d = event.data
    if (d.open) {
        document.getElementById('app').classList.remove('hidden')
    }
});

