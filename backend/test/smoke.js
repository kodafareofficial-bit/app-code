// End-to-end smoke test: node --disable-warning=ExperimentalWarning test/smoke.js
const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const assert = require('assert');

process.env.DATA_DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'co-test-'));
process.env.ADMIN_EMAIL = 'Admin@Test.ir';
process.env.ADMIN_PASSWORD = 'S3cret!pass';
process.env.DEV_RETURN_OTP = '1';

const { server } = require('../src/server');
const { buildIppanelRequest } = require('../src/sms');

let base;
let passed = 0;
async function call(method, url, { token, body, raw } = {}) {
  const r = await fetch(base + url, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (raw) return r;
  let data = {};
  try { data = await r.json(); } catch (_) {}
  return { status: r.status, data };
}
async function t(name, fn) {
  try {
    await fn();
    passed++;
    console.log('  ok  ', name);
  } catch (e) {
    console.error('  FAIL', name, '\n      ', e.message);
    process.exitCode = 1;
  }
}

(async () => {
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;

  // mock ippanel
  const received = [];
  const mock = http.createServer((req, res) => {
    let b = '';
    req.on('data', (c) => (b += c));
    req.on('end', () => {
      received.push({ url: req.url, auth: req.headers.authorization, body: JSON.parse(b) });
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end('{"ok":true}');
    });
  });
  await new Promise((r) => mock.listen(0, '127.0.0.1', r));
  const mockBase = `http://127.0.0.1:${mock.address().port}/v1`;

  let userToken, adminToken, userId, svcId, catId;

  await t('health + bootstrap with seeded content', async () => {
    assert.equal((await call('GET', '/api/health')).data.ok, true);
    const b = (await call('GET', '/api/public/bootstrap')).data;
    assert.equal(b.settings.company_name, 'کد آفر');
    assert.ok(b.services.length >= 3 && b.categories.length >= 3);
    assert.ok(!('sms_token' in b.settings), 'sms token must never be public');
  });

  await t('otp: invalid phone rejected', async () => {
    assert.equal((await call('POST', '/api/auth/request-otp', { body: { phone: '123' } })).status, 400);
  });

  let devCode;
  await t('otp: request with Persian digits, resend rate-limited', async () => {
    const r = await call('POST', '/api/auth/request-otp', { body: { phone: '۰۹۱۲۳۴۵۶۷۸۹' } });
    assert.equal(r.status, 200);
    devCode = r.data.dev_code;
    assert.match(devCode, /^\d{5}$/);
    assert.equal((await call('POST', '/api/auth/request-otp', { body: { phone: '09123456789' } })).status, 429);
  });

  await t('otp: wrong code rejected, right code logs in as new user', async () => {
    const wrong = devCode === '11111' ? '22222' : '11111';
    assert.equal((await call('POST', '/api/auth/verify-otp', { body: { phone: '09123456789', code: wrong } })).status, 400);
    const r = await call('POST', '/api/auth/verify-otp', { body: { phone: '09123456789', code: devCode } });
    assert.equal(r.status, 200);
    assert.equal(r.data.is_new, true);
    assert.equal(r.data.user.phone, '+989123456789');
    userToken = r.data.token;
    userId = r.data.user.id;
    // code is single-use
    assert.equal((await call('POST', '/api/auth/verify-otp', { body: { phone: '09123456789', code: devCode } })).status, 400);
  });

  await t('otp: 5 wrong attempts lock the code', async () => {
    const r = await call('POST', '/api/auth/request-otp', { body: { phone: '09351112233' } });
    const good = r.data.dev_code;
    const bad = good === '10000' ? '10001' : '10000';
    for (let i = 0; i < 5; i++) await call('POST', '/api/auth/verify-otp', { body: { phone: '09351112233', code: bad } });
    assert.equal((await call('POST', '/api/auth/verify-otp', { body: { phone: '09351112233', code: good } })).status, 429);
  });

  await t('profile: get / update / notif toggle', async () => {
    assert.equal((await call('GET', '/api/me', { token: userToken })).data.user.id, userId);
    const r = await call('PUT', '/api/me', { token: userToken, body: { name: 'علی رضایی', email: 'a@b.ir', city: 'تهران', bio: 'سلام', notif_enabled: false } });
    assert.equal(r.data.user.name, 'علی رضایی');
    assert.equal(r.data.user.notif_enabled, 0);
    assert.equal((await call('GET', '/api/me')).status, 401);
  });

  await t('admin: wrong password rejected; user token cannot access admin', async () => {
    assert.equal((await call('POST', '/api/admin/login', { body: { email: 'admin@test.ir', password: 'nope' } })).status, 401);
    assert.equal((await call('GET', '/api/admin/stats', { token: userToken })).status, 403);
    assert.equal((await call('GET', '/api/admin/stats')).status, 401);
  });

  await t('admin: login (case-insensitive email) + stats + users list/search', async () => {
    const r = await call('POST', '/api/admin/login', { body: { email: ' ADMIN@test.ir ', password: 'S3cret!pass' } });
    assert.equal(r.status, 200);
    adminToken = r.data.token;
    const st = (await call('GET', '/api/admin/stats', { token: adminToken })).data;
    assert.equal(st.users_total, 1); // only verified users are created
    const list = (await call('GET', '/api/admin/users?q=9123456789', { token: adminToken })).data;
    assert.equal(list.total, 1);
    assert.equal(list.items[0].name, 'علی رضایی');
    assert.equal((await call('GET', '/api/admin/users?q=' + encodeURIComponent('رضایی'), { token: adminToken })).data.total, 1);
  });

  await t('admin: CSV export (BOM, excel-safe phone, formula injection guard)', async () => {
    await call('PUT', '/api/admin/users/' + userId, { token: adminToken, body: { name: '=cmd|calc' } });
    const r = await call('GET', '/api/admin/users/export.csv', { token: adminToken, raw: true });
    assert.match(r.headers.get('content-type'), /text\/csv/);
    const buf = Buffer.from(await r.arrayBuffer());
    assert.deepEqual([...buf.subarray(0, 3)], [0xef, 0xbb, 0xbf], 'UTF-8 BOM so Excel shows Persian correctly');
    const txt = buf.toString('utf8');
    assert.ok(txt.includes('id,phone,name,email'));
    assert.ok(txt.includes('="09123456789"'));
    assert.ok(txt.includes("'=cmd|calc"), 'formula must be neutralised');
    assert.equal((await call('GET', '/api/admin/users/export.csv', { raw: true })).status, 401);
    await call('PUT', '/api/admin/users/' + userId, { token: adminToken, body: { name: 'علی رضایی' } });
  });

  await t('content: category + service CRUD; inactive hidden from users', async () => {
    catId = (await call('POST', '/api/admin/categories', { token: adminToken, body: { title: 'هوش مصنوعی', icon: 'memory', sort: 9 } })).data.item.id;
    const s = await call('POST', '/api/admin/services', {
      token: adminToken,
      body: { title: 'چت‌بات', description: 'ساخت چت‌بات', category_id: catId, icon: 'chat', price: '۵ میلیون', sort: 5, active: true },
    });
    assert.equal(s.status, 200);
    svcId = s.data.item.id;
    let b = (await call('GET', '/api/public/bootstrap')).data;
    assert.ok(b.services.some((x) => x.id === svcId));
    await call('PUT', '/api/admin/services/' + svcId, { token: adminToken, body: { active: false } });
    b = (await call('GET', '/api/public/bootstrap')).data;
    assert.ok(!b.services.some((x) => x.id === svcId), 'inactive service must be hidden');
    await call('PUT', '/api/admin/services/' + svcId, { token: adminToken, body: { active: true, category_id: null, title: 'چت‌بات هوشمند' } });
    const item = (await call('GET', '/api/admin/services', { token: adminToken })).data.items.find((x) => x.id === svcId);
    assert.equal(item.category_id, null);
    assert.equal(item.title, 'چت‌بات هوشمند');
    assert.equal((await call('POST', '/api/admin/services', { token: adminToken, body: { title: '  ' } })).status, 400);
    await call('DELETE', '/api/admin/services/' + svcId, { token: adminToken });
    await call('DELETE', '/api/admin/categories/' + catId, { token: adminToken });
    const b2 = (await call('GET', '/api/public/bootstrap')).data;
    assert.ok(!b2.services.some((x) => x.id === svcId));
  });

  await t('socials + banners CRUD appear in bootstrap', async () => {
    await call('POST', '/api/admin/socials', { token: adminToken, body: { platform: 'telegram', url: 'https://t.me/codeoffer', sort: 1 } });
    await call('POST', '/api/admin/banners', { token: adminToken, body: { title: 'جشنواره', image: '/uploads/x.png', link: 'https://example.com' } });
    const b = (await call('GET', '/api/public/bootstrap')).data;
    assert.equal(b.socials[0].platform, 'telegram');
    assert.equal(b.banners[0].title, 'جشنواره');
  });

  await t('upload: png accepted & served, non-image rejected', async () => {
    const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');
    const r = await call('POST', '/api/admin/upload', { token: adminToken, body: { filename: 'a.png', data: png.toString('base64') } });
    assert.equal(r.status, 200);
    assert.match(r.data.url, /^\/uploads\/[a-f0-9]{24}\.png$/);
    const g = await fetch(base + r.data.url);
    assert.equal(g.status, 200);
    assert.equal(g.headers.get('content-type'), 'image/png');
    const bad = await call('POST', '/api/admin/upload', { token: adminToken, body: { filename: 'x.png', data: Buffer.from('<script>alert(1)</script>').toString('base64') } });
    assert.equal(bad.status, 400);
    assert.equal((await call('POST', '/api/admin/upload', { body: { data: 'AAAA' } })).status, 401);
    assert.equal((await fetch(base + '/uploads/..%2f..%2fetc%2fpasswd')).status, 404);
  });

  await t('notifications: admin sends, user receives, last id advances', async () => {
    const before = (await call('GET', '/api/public/bootstrap')).data.last_notification_id;
    const r = await call('POST', '/api/admin/notifications', { token: adminToken, body: { title: 'تخفیف ویژه', body: '۲۰٪', link: 'https://x.ir' } });
    assert.equal(r.status, 200);
    const after = (await call('GET', '/api/public/bootstrap')).data.last_notification_id;
    assert.ok(after > before);
    const list = (await call('GET', '/api/notifications', { token: userToken })).data.items;
    assert.equal(list[0].title, 'تخفیف ویژه');
    assert.equal((await call('GET', '/api/notifications')).status, 401);
    assert.equal((await call('POST', '/api/admin/notifications', { token: adminToken, body: {} })).status, 400);
  });

  await t('settings: branding changes reach users; sms token never leaks; blank token kept', async () => {
    await call('PUT', '/api/admin/settings', {
      token: adminToken,
      body: { company_name: 'کد آفر پلاس', primary_color: '#112233', sms_token: 'SECRET-TOKEN', sms_enabled: '1', evil_key: 'x' },
    });
    const pub = (await call('GET', '/api/public/bootstrap')).data.settings;
    assert.equal(pub.company_name, 'کد آفر پلاس');
    assert.equal(pub.primary_color, '#112233');
    assert.ok(!JSON.stringify(pub).includes('SECRET-TOKEN'));
    let s = (await call('GET', '/api/admin/settings', { token: adminToken })).data.settings;
    assert.equal(s.sms_token, '');
    assert.equal(s.sms_token_set, '1');
    assert.ok(!('evil_key' in s));
    await call('PUT', '/api/admin/settings', { token: adminToken, body: { sms_token: '' } });
    s = (await call('GET', '/api/admin/settings', { token: adminToken })).data.settings;
    assert.equal(s.sms_token_set, '1', 'blank token must not erase the saved one');
  });

  await t('ippanel: pattern request is built per the Edge API spec', async () => {
    const req = buildIppanelRequest('+989123456789', '54321', {
      sms_base_url: 'https://edge.ippanel.com/v1/', sms_token: 'TK', sms_from_number: '+983000505',
      sms_mode: 'pattern', sms_pattern_code: 'abc123', sms_pattern_param: 'otp',
    });
    assert.equal(req.url, 'https://edge.ippanel.com/v1/api/send');
    assert.equal(req.headers.Authorization, 'TK');
    assert.deepEqual(req.body, { sending_type: 'pattern', from_number: '+983000505', code: 'abc123', recipients: ['+989123456789'], params: { otp: '54321' } });
    const ws = buildIppanelRequest('+989123456789', '54321', { sms_base_url: 'x', sms_token: 'TK', sms_from_number: '+98PRO', sms_mode: 'webservice', sms_message_template: 'کد {code} / {code}' });
    assert.deepEqual(ws.body, { sending_type: 'webservice', from_number: '+98PRO', message: 'کد 54321 / 54321', params: { recipients: ['+989123456789'] } });
  });

  await t('ippanel: OTP is actually delivered to the configured gateway', async () => {
    await call('PUT', '/api/admin/settings', {
      token: adminToken,
      body: { sms_enabled: '1', sms_base_url: mockBase, sms_token: 'MOCK-TOKEN', sms_from_number: '+983000505', sms_mode: 'pattern', sms_pattern_code: 'pat1', sms_pattern_param: 'code' },
    });
    const r = await call('POST', '/api/auth/request-otp', { body: { phone: '09361234567' } });
    assert.equal(r.status, 200);
    assert.ok(!('dev_code' in r.data), 'code must not be returned when SMS is live');
    assert.equal(received.length, 1);
    assert.equal(received[0].url, '/v1/api/send');
    assert.equal(received[0].auth, 'MOCK-TOKEN');
    assert.equal(received[0].body.sending_type, 'pattern');
    assert.deepEqual(received[0].body.recipients, ['+989361234567']);
    assert.match(received[0].body.params.code, /^\d{5}$/);
    // and that code logs the user in
    const v = await call('POST', '/api/auth/verify-otp', { body: { phone: '09361234567', code: received[0].body.params.code } });
    assert.equal(v.status, 200);
  });

  await t('ippanel: gateway failure -> 502 and no usable code left behind', async () => {
    await call('PUT', '/api/admin/settings', { token: adminToken, body: { sms_base_url: 'http://127.0.0.1:1/v1' } });
    const r = await call('POST', '/api/auth/request-otp', { body: { phone: '09371234567' } });
    assert.equal(r.status, 502);
    assert.equal((await call('POST', '/api/auth/verify-otp', { body: { phone: '09371234567', code: '12345' } })).status, 400);
    await call('PUT', '/api/admin/settings', { token: adminToken, body: { sms_enabled: '0' } });
  });

  await t('blocking a user kills their session and login', async () => {
    await call('PUT', '/api/admin/users/' + userId, { token: adminToken, body: { blocked: true } });
    assert.equal((await call('GET', '/api/me', { token: userToken })).status, 403);
    assert.equal((await call('POST', '/api/auth/request-otp', { body: { phone: '09123456789' } })).status, 403);
    await call('PUT', '/api/admin/users/' + userId, { token: adminToken, body: { blocked: false } });
    assert.equal((await call('GET', '/api/me', { token: userToken })).status, 200);
  });

  await t('tampered / expired tokens rejected', async () => {
    const parts = userToken.split('.');
    const forged = parts[0] + '.' + Buffer.from(JSON.stringify({ role: 'admin', id: 1, exp: 9999999999 })).toString('base64url') + '.' + parts[2];
    assert.equal((await call('GET', '/api/admin/stats', { token: forged })).status, 401);
  });

  await t('admin password change works and old one stops working', async () => {
    assert.equal((await call('PUT', '/api/admin/account', { token: adminToken, body: { current_password: 'wrong', new_password: 'Another#Pass1' } })).status, 400);
    assert.equal((await call('PUT', '/api/admin/account', { token: adminToken, body: { current_password: 'S3cret!pass', new_password: 'short' } })).status, 400);
    assert.equal((await call('PUT', '/api/admin/account', { token: adminToken, body: { current_password: 'S3cret!pass', new_password: 'Another#Pass1' } })).status, 200);
    assert.equal((await call('POST', '/api/admin/login', { body: { email: 'admin@test.ir', password: 'S3cret!pass' } })).status, 401);
    assert.equal((await call('POST', '/api/admin/login', { body: { email: 'admin@test.ir', password: 'Another#Pass1' } })).status, 200);
  });

  await t('user can delete own account', async () => {
    assert.equal((await call('DELETE', '/api/me', { token: userToken })).status, 200);
    assert.equal((await call('GET', '/api/me', { token: userToken })).status, 401);
  });

  console.log(`\n${passed} checks passed${process.exitCode ? ', SOME FAILED' : ''}`);
  mock.close();
  server.close();
  process.exit(process.exitCode || 0);
})();
