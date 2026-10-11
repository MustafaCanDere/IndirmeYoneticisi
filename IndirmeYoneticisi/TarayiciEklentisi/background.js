// config.js (PORT ve TOKEN) uygulama her acildiginda otomatik yazilir.
importScripts('config.js');

const BASE = 'http://127.0.0.1:' + PORT;

async function enabled() {
  const s = await chrome.storage.local.get({ on: true });
  return s.on;
}

async function paintBadge() {
  const on = await enabled();
  chrome.action.setBadgeText({ text: on ? '' : 'KAPALI' });
  chrome.action.setBadgeBackgroundColor({ color: '#888888' });
}

// Simgeye tiklayinca yakalamayi ac/kapat (giris gerektiren indirmeler icin faydali)
chrome.action.onClicked.addListener(async () => {
  const on = await enabled();
  await chrome.storage.local.set({ on: !on });
  paintBadge();
});
chrome.runtime.onStartup.addListener(paintBadge);
chrome.runtime.onInstalled.addListener(paintBadge);

chrome.downloads.onCreated.addListener(async (item) => {
  try {
    if (!(await enabled())) return;
    const url = item.finalUrl || item.url;
    if (!/^https?:/i.test(url)) return;

    // Dosya adi genelde birkac yuz ms sonra belli olur
    await new Promise((r) => setTimeout(r, 400));
    const [cur] = await chrome.downloads.search({ id: item.id });
    if (!cur || cur.state !== 'in_progress') return; // zaten bitmis/iptal

    const name = (cur.filename || '').split(/[\\/]/).pop();
    const r = await fetch(BASE + '/add', {
      method: 'POST',
      headers: { 'X-Token': TOKEN, 'Content-Type': 'application/json' },
      body: JSON.stringify({ url: cur.finalUrl || cur.url, filename: name }),
    });
    if (r.ok) {
      chrome.downloads.cancel(item.id, () => chrome.downloads.erase({ id: item.id }));
    }
    // Uygulama kapaliysa/hata varsa tarayici indirmeyi normal sekilde surdurur
  } catch (e) {
    // Uygulamaya ulasilamadi: tarayici kendi indirmesine devam eder
  }
});

paintBadge();
