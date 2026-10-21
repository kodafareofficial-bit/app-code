const { db } = require('./db');

function getSettings() {
  const out = {};
  for (const r of db.prepare('SELECT key,value FROM settings').all()) out[r.key] = r.value;
  return out;
}

/** 09123456789 / 9123456789 / +989123456789 / 989123456789 -> +989123456789 */
function normalizePhone(input) {
  let p = String(input || '').replace(/[^\d+]/g, '');
  if (p.startsWith('+98')) p = p.slice(3);
  else if (p.startsWith('0098')) p = p.slice(4);
  else if (p.startsWith('98') && p.length === 12) p = p.slice(2);
  else if (p.startsWith('0')) p = p.slice(1);
  if (!/^9\d{9}$/.test(p)) return null;
  return '+98' + p;
}

/** Builds the ippanel Edge request (exported for tests). */
function buildIppanelRequest(phone, code, s) {
  const base = String(s.sms_base_url || '').replace(/\/+$/, '');
  const url = `${base}/api/send`;
  let body;
  if (s.sms_mode === 'webservice') {
    body = {
      sending_type: 'webservice',
      from_number: s.sms_from_number,
      message: String(s.sms_message_template || '{code}').split('{code}').join(code),
      params: { recipients: [phone] },
    };
  } else {
    body = {
      sending_type: 'pattern',
      from_number: s.sms_from_number,
      code: s.sms_pattern_code,
      recipients: [phone],
      params: { [s.sms_pattern_param || 'code']: code },
    };
  }
  return { url, body, headers: { Authorization: s.sms_token, 'Content-Type': 'application/json' } };
}

async function sendViaIppanel(phone, code, s = getSettings()) {
  const { url, body, headers } = buildIppanelRequest(phone, code, s);
  const res = await fetch(url, {
    method: 'POST',
    headers,
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(15000),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`ippanel ${res.status}: ${text.slice(0, 300)}`);
  return text;
}

/** Sends an OTP. Returns { sent, dev }. In dev mode (SMS not configured) the code is only logged. */
async function sendOtp(phone, code) {
  const s = getSettings();
  const ready =
    s.sms_enabled === '1' && s.sms_token && s.sms_from_number && (s.sms_mode === 'webservice' || s.sms_pattern_code);
  if (!ready) {
    console.log(`[DEV-OTP] SMS is not configured. Code for ${phone}: ${code}`);
    return { sent: false, dev: true };
  }
  await sendViaIppanel(phone, code, s);
  return { sent: true, dev: false };
}

module.exports = { sendOtp, normalizePhone, sendViaIppanel, buildIppanelRequest, getSettings };
