window.addEventListener('message', (event) => {
    const d = event.data
    if (d.action === 'open') {
        document.getElementById('app').classList.remove('hidden')
        const sel = document.getElementById('item')
        sel.innerHTML = ''
        d.drugs.forEach(dr => {
            const opt = document.createElement('option')
            opt.value = dr.item
            opt.text = dr.label + ' - $' + dr.basePrice
            sel.add(opt)
        })
        document.getElementById('xp').innerText = 'XP: ' + (d.xp or 0)
    } else if (d.action === 'close') {
        document.getElementById('app').classList.add('hidden')
    } else if (d.action === 'error') {
        showMsg(d.text, true)
    }
})

function showMsg(text, err) {
    const el = document.getElementById('msg')
    el.innerText = text
    el.style.color = err ? '#f56565' : '#48bb78'
}

document.getElementById('sell').addEventListener('click', () => {
    const item = document.getElementById('item').value
    const amount = document.getElementById('amount').value
    fetch(`https://${GetParentResourceName()}/sell`, { method: 'POST', body: JSON.stringify({ item, amount }) })
    .then(resp => resp.json()).then(r => { if (!r.ok) showMsg(r.msg, true) else showMsg('Sold!', false) })
})

document.getElementById('close').addEventListener('click', () => {
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' })
})

// NUI callbacks
window.addEventListener('keydown', function(e) { if (e.key === 'Escape') fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' }) })
