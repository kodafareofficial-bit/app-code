const http = require('http');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const { db, DATA_DIR, hashPassword, verifyPassword, transaction } = require('./db');
const { sendOtp, normalizePhone, sendViaIppanel, getSettings } = require('./sms');

// ---------------------------------------------------------------- secrets
let JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  const f = path.join(DATA_DIR, 'jwt.secret');
  if (fs.existsSync(f)) JWT_SECRET = fs.readFileSync(f, 'utf8').trim();
  else {
    JWT_SECRET = crypto.randomBytes(48).toString('hex');
    fs.writeFileSync(f, JWT_SECRET, { mode: 0o600 });
  }
}

// ---------------------------------------------------------------- jwt (HS256)
const b64u = (b) => Buffer.from(b).toString('base64url');
function signJwt(payload, ttlSec) {
  const h = b64u(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const p = b64u(JSON.stringify({ ...payload, exp: Math.floor(Date.now() / 1000) + ttlSec }));
  const s = crypto.createHmac('sha256', JWT_SECRET).update(`${h}.${p}`).digest('base64url');
  return `${h}.${p}.${s}`;
}
function verifyJwt(token) {
  const parts = String(token).split('.');
  if (parts.length !== 3) throw new Error('bad token');
  const exp = crypto.createHmac('sha256', JWT_SECRET).update(`${parts[0]}.${parts[1]}`).digest();
  const got = Buffer.from(parts[2], 'base64url');
  if (exp.length !== got.length || !crypto.timingSafeEqual(exp, got)) throw new Error('bad signature');
  const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  if (!payload.exp || payload.exp < Date.now() / 1000) throw new Error('expired');
  return payload;
}

// ---------------------------------------------------------------- helpers
class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}
const fail = (status, msg) => {
  throw new HttpError(status, msg);
};

const faDigits = (s) =>
  String(s ?? '')
    .replace(/[۰-۹]/g, (d) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(d))
    .replace(/[٠-٩]/g, (d) => '٠١٢٣٤٥٦٧٨٩'.indexOf(d));

const hits = new Map();
function rateLimit(key, max, windowMs) {
  const now = Date.now();
  const arr = (hits.get(key) || []).filter((t) => now - t < windowMs);
  if (arr.length >= max) return false;
  arr.push(now);
  hits.set(key, arr);
  return true;
}
setInterval(() => hits.clear(), 3600 * 1000).unref();

const otpHash = (phone, code) => crypto.createHmac('sha256', JWT_SECRET).update(`${phone}:${code}`).digest('hex');
const safeEq = (a, b) => {
  const x = Buffer.from(a);
  const y = Buffer.from(b);
  return x.length === y.length && crypto.timingSafeEqual(x, y);
};

const PUBLIC_SETTING_KEYS = [
  'company_name', 'company_name_en', 'tagline', 'about', 'logo', 'primary_color',
  'accent_color', 'splash_color', 'splash_text', 'support_phone', 'support_email',
];
function publicSettings() {
  const s = getSettings();
  const o = {};
  for (const k of PUBLIC_SETTING_KEYS) o[k] = s[k] ?? '';
  return o;
}
const str = (v, max) => String(v ?? '').slice(0, max);
const flag = (v) => (v === true || v === 1 || v === '1' ? 1 : 0);

// ---------------------------------------------------------------- router
const routes = [];
function route(method, pattern, opts, handler) {
  if (typeof opts === 'function') {
    handler = opts;
    opts = {};
  }
  const keys = [];
  const re = new RegExp('^' + pattern.replace(/:([a-z_]+)/g, (_, k) => (keys.push(k), '([^/]+)')) + '/?$');
  routes.push({ method, re, keys, handler, auth: opts.auth, limit: opts.limit || 1024 * 1024 });
}

function authenticate(req, role) {
  const h = req.headers.authorization || '';
  const t = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!t) fail(401, 'نیاز به ورود');
  let p;
  try {
    p = verifyJwt(t);
  } catch (_) {
    fail(401, 'نشست نامعتبر یا منقضی شده');
  }
  if (p.role !== role) fail(403, 'دسترسی غیرمجاز');
  if (role === 'user') {
    const u = db.prepare('SELECT * FROM users WHERE id=?').get(p.id);
    if (!u) fail(401, 'کاربر یافت نشد');
    if (u.blocked) fail(403, 'حساب شما مسدود شده است');
    return u;
  }
  const a = db.prepare('SELECT id,email FROM admins WHERE id=?').get(p.id);
  if (!a) fail(401, 'نشست نامعتبر است');
  return a;
}

function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > limit) {
        reject(new HttpError(413, 'حجم درخواست زیاد است'));
        req.destroy();
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => {
      if (!size) return resolve({});
      try {
        const v = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        resolve(v && typeof v === 'object' ? v : {});
      } catch (_) {
        reject(new HttpError(400, 'بدنه درخواست JSON معتبر نیست'));
      }
    });
    req.on('error', reject);
  });
}

function send(res, status, data, headers = {}) {
  const body = typeof data === 'string' || Buffer.isBuffer(data) ? data : JSON.stringify(data);
  res.writeHead(status, {
    'Content-Type': typeof data === 'string' || Buffer.isBuffer(data) ? 'text/plain; charset=utf-8' : 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS',
    'X-Content-Type-Options': 'nosniff',
    ...headers,
  });
  res.end(body);
}

const MIME = { png: 'image/png', jpg: 'image/jpeg', webp: 'image/webp', gif: 'image/gif' };

const server = http.createServer(async (req, res) => {
  try {
    const u = new URL(req.url, 'http://x');
    if (req.method === 'OPTIONS') return send(res, 204, '');

    // static uploads
    if (req.method === 'GET' && u.pathname.startsWith('/uploads/')) {
      const name = u.pathname.slice('/uploads/'.length);
      if (!/^[a-f0-9]{24}\.(png|jpg|webp|gif)$/.test(name)) return send(res, 404, { error: 'یافت نشد' });
      const file = path.join(DATA_DIR, 'uploads', name);
      if (!fs.existsSync(file)) return send(res, 404, { error: 'یافت نشد' });
      res.writeHead(200, {
        'Content-Type': MIME[name.split('.').pop()],
        'Cache-Control': 'public, max-age=604800, immutable',
        'Access-Control-Allow-Origin': '*',
        'X-Content-Type-Options': 'nosniff',
      });
      return fs.createReadStream(file).pipe(res);
    }

    if (req.method === 'GET' && u.pathname === '/') {
      return send(res, 200, { name: 'Code Offer API', ok: true });
    }

    for (const r of routes) {
      if (r.method !== req.method) continue;
      const m = r.re.exec(u.pathname);
      if (!m) continue;
      const params = {};
      r.keys.forEach((k, i) => (params[k] = decodeURIComponent(m[i + 1])));
      const ctx = {
        req,
        res,
        params,
        query: Object.fromEntries(u.searchParams),
        ip: String(req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').split(',')[0].trim(),
      };
      if (r.auth) {
        const who = authenticate(req, r.auth);
        if (r.auth === 'user') ctx.user = who;
        else ctx.admin = who;
      }
      ctx.body = req.method === 'POST' || req.method === 'PUT' ? await readBody(req, r.limit) : {};
      const out = await r.handler(ctx);
      if (res.writableEnded) return;
      if (out && out.__raw) return send(res, 200, out.body, out.headers);
      return send(res, 200, out ?? { ok: true });
    }
    send(res, 404, { error: 'مسیر یافت نشد' });
  } catch (e) {
    if (e instanceof HttpError) return send(res, e.status, { error: e.message });
    console.error(e);
    send(res, 500, { error: 'خطای داخلی سرور' });
  }
});

// ================================================================ PUBLIC
route('GET', '/api/health', () => ({ ok: true }));

route('GET', '/api/public/bootstrap', () => ({
  settings: publicSettings(),
  banners: db.prepare('SELECT * FROM banners WHERE active=1 ORDER BY sort,id').all(),
  categories: db.prepare('SELECT * FROM categories WHERE active=1 ORDER BY sort,id').all(),
  services: db.prepare('SELECT * FROM services WHERE active=1 ORDER BY sort,id').all(),
  socials: db.prepare('SELECT * FROM socials ORDER BY sort,id').all(),
  last_notification_id: db.prepare('SELECT COALESCE(MAX(id),0) m FROM notifications').get().m,
}));

// ================================================================ CUSTOMER AUTH (phone + SMS OTP)
route('POST', '/api/auth/request-otp', async ({ body, ip }) => {
  const phone = normalizePhone(faDigits(body.phone));
  if (!phone) fail(400, 'شماره موبایل معتبر نیست');
  if (!rateLimit('otp-ip:' + ip, 20, 3600 * 1000)) fail(429, 'تعداد درخواست زیاد است، بعداً تلاش کنید');
  const now = Date.now();
  const row = db.prepare('SELECT * FROM otps WHERE phone=?').get(phone);
  if (row && now - row.last_sent < 60 * 1000) {
    fail(429, `لطفاً ${Math.ceil((60000 - (now - row.last_sent)) / 1000)} ثانیه صبر کنید`);
  }
  const existing = db.prepare('SELECT blocked FROM users WHERE phone=?').get(phone);
  if (existing && existing.blocked) fail(403, 'حساب شما مسدود شده است');

  const code = String(crypto.randomInt(10000, 100000)); // 5 digits
  db.prepare(
    `INSERT INTO otps(phone,code_hash,expires_at,attempts,last_sent) VALUES(?,?,?,0,?)
     ON CONFLICT(phone) DO UPDATE SET code_hash=excluded.code_hash, expires_at=excluded.expires_at, attempts=0, last_sent=excluded.last_sent`
  ).run(phone, otpHash(phone, code), now + 2 * 60 * 1000, now);
  try {
    const r = await sendOtp(phone, code);
    const out = { ok: true, expires_in: 120 };
    if (r.dev && process.env.DEV_RETURN_OTP === '1') out.dev_code = code;
    return out;
  } catch (e) {
    console.error('SMS error:', e.message);
    db.prepare('DELETE FROM otps WHERE phone=?').run(phone);
    fail(502, 'ارسال پیامک ناموفق بود. تنظیمات پنل پیامک را بررسی کنید.');
  }
});

route('POST', '/api/auth/verify-otp', ({ body }) => {
  const phone = normalizePhone(faDigits(body.phone));
  const code = faDigits(body.code).trim();
  if (!phone || !code) fail(400, 'اطلاعات ناقص است');
  const row = db.prepare('SELECT * FROM otps WHERE phone=?').get(phone);
  if (!row || row.expires_at < Date.now()) fail(400, 'کد منقضی شده است، دوباره درخواست دهید');
  if (row.attempts >= 5) fail(429, 'تعداد تلاش بیش از حد مجاز است');
  if (!safeEq(otpHash(phone, code), row.code_hash)) {
    db.prepare('UPDATE otps SET attempts=attempts+1 WHERE phone=?').run(phone);
    fail(400, 'کد وارد شده صحیح نیست');
  }
  db.prepare('DELETE FROM otps WHERE phone=?').run(phone);
  let u = db.prepare('SELECT * FROM users WHERE phone=?').get(phone);
  let isNew = false;
  if (!u) {
    const id = db.prepare('INSERT INTO users(phone) VALUES(?)').run(phone).lastInsertRowid;
    u = db.prepare('SELECT * FROM users WHERE id=?').get(id);
    isNew = true;
  }
  if (u.blocked) fail(403, 'حساب شما مسدود شده است');
  db.prepare("UPDATE users SET last_login=datetime('now') WHERE id=?").run(u.id);
  u = db.prepare('SELECT * FROM users WHERE id=?').get(u.id);
  return { token: signJwt({ role: 'user', id: u.id }, 90 * 86400), user: u, is_new: isNew };
});

route('GET', '/api/me', { auth: 'user' }, ({ user }) => ({ user }));

route('PUT', '/api/me', { auth: 'user' }, ({ user, body }) => {
  db.prepare('UPDATE users SET name=?, email=?, city=?, bio=?, notif_enabled=? WHERE id=?').run(
    str(body.name ?? user.name, 80),
    str(body.email ?? user.email, 120),
    str(body.city ?? user.city, 80),
    str(body.bio ?? user.bio, 500),
    body.notif_enabled === undefined ? user.notif_enabled : flag(body.notif_enabled),
    user.id
  );
  return { user: db.prepare('SELECT * FROM users WHERE id=?').get(user.id) };
});

route('DELETE', '/api/me', { auth: 'user' }, ({ user }) => {
  db.prepare('DELETE FROM users WHERE id=?').run(user.id);
  return { ok: true };
});

route('GET', '/api/notifications', { auth: 'user' }, () => ({
  items: db.prepare('SELECT * FROM notifications ORDER BY id DESC LIMIT 100').all(),
}));

// ================================================================ ADMIN
route('POST', '/api/admin/login', ({ body, ip }) => {
  if (!rateLimit('adm-ip:' + ip, 10, 15 * 60 * 1000)) fail(429, 'تلاش بیش از حد، بعداً امتحان کنید');
  const email = String(body.email || '').trim().toLowerCase();
  const a = db.prepare('SELECT * FROM admins WHERE email=?').get(email);
  if (!a || !verifyPassword(body.password || '', a.password_hash)) fail(401, 'ایمیل یا رمز عبور اشتباه است');
  return { token: signJwt({ role: 'admin', id: a.id }, 30 * 86400), email: a.email };
});

const A = { auth: 'admin' };

route('GET', '/api/admin/stats', A, () => {
  const one = (q) => db.prepare(q).get().c;
  return {
    users_total: one('SELECT COUNT(*) c FROM users'),
    users_today: one("SELECT COUNT(*) c FROM users WHERE date(created_at)=date('now')"),
    users_week: one("SELECT COUNT(*) c FROM users WHERE created_at >= datetime('now','-7 days')"),
    users_blocked: one('SELECT COUNT(*) c FROM users WHERE blocked=1'),
    services: one('SELECT COUNT(*) c FROM services'),
    banners: one('SELECT COUNT(*) c FROM banners'),
    notifications: one('SELECT COUNT(*) c FROM notifications'),
    recent_users: db.prepare('SELECT id,phone,name,created_at FROM users ORDER BY id DESC LIMIT 5').all(),
  };
});

// ---- users
route('GET', '/api/admin/users', A, ({ query }) => {
  const q = faDigits(String(query.q || '').trim());
  const page = Math.max(1, parseInt(query.page) || 1);
  const size = Math.min(100, Math.max(1, parseInt(query.size) || 30));
  const where = q ? 'WHERE phone LIKE ? OR name LIKE ? OR email LIKE ?' : '';
  const like = `%${q}%`;
  const args = q ? [like, like, like] : [];
  const total = db.prepare(`SELECT COUNT(*) c FROM users ${where}`).get(...args).c;
  const items = db.prepare(`SELECT * FROM users ${where} ORDER BY id DESC LIMIT ? OFFSET ?`).all(...args, size, (page - 1) * size);
  return { items, total, page, size };
});

route('GET', '/api/admin/users/export.csv', A, () => {
  const rows = db.prepare('SELECT * FROM users ORDER BY id').all();
  const esc = (v) => {
    let s = String(v ?? '');
    if (/^[=+\-@\t\r]/.test(s)) s = "'" + s; // CSV / Excel formula-injection guard
    return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const head = ['id', 'phone', 'name', 'email', 'city', 'blocked', 'created_at', 'last_login'];
  // phone is validated digits only (+98...), written as ="09..." so Excel keeps the leading zero
  const cell = (r, h) => (h === 'phone' ? `="${String(r[h]).replace(/^\+98/, '0').replace(/[^\d]/g, '')}"` : esc(r[h]));
  const lines = [head.join(',')].concat(rows.map((r) => head.map((h) => cell(r, h)).join(',')));
  return {
    __raw: true,
    body: '﻿' + lines.join('\r\n'),
    headers: {
      'Content-Type': 'text/csv; charset=utf-8',
      'Content-Disposition': 'attachment; filename="codeoffer-users.csv"',
    },
  };
});

route('GET', '/api/admin/users/:id', A, ({ params }) => {
  const u = db.prepare('SELECT * FROM users WHERE id=?').get(params.id);
  if (!u) fail(404, 'یافت نشد');
  return { user: u };
});

route('PUT', '/api/admin/users/:id', A, ({ params, body }) => {
  const u = db.prepare('SELECT * FROM users WHERE id=?').get(params.id);
  if (!u) fail(404, 'یافت نشد');
  db.prepare('UPDATE users SET name=?, email=?, city=?, bio=?, blocked=? WHERE id=?').run(
    str(body.name ?? u.name, 80),
    str(body.email ?? u.email, 120),
    str(body.city ?? u.city, 80),
    str(body.bio ?? u.bio, 500),
    body.blocked === undefined ? u.blocked : flag(body.blocked),
    u.id
  );
  return { user: db.prepare('SELECT * FROM users WHERE id=?').get(u.id) };
});

route('DELETE', '/api/admin/users/:id', A, ({ params }) => {
  db.prepare('DELETE FROM users WHERE id=?').run(params.id);
  return { ok: true };
});

// ---- generic CRUD for content tables (table/field names are constants below, never user input)
function crud(name, table, fields, required) {
  const isNum = (f) => ['sort', 'active', 'category_id'].includes(f);
  const clean = (f, v) => {
    if (f === 'active') return flag(v);
    if (f === 'sort') return Number.isFinite(+v) ? Math.trunc(+v) : 0;
    if (f === 'category_id') return v === null || v === '' || v === undefined ? null : Math.trunc(+v) || null;
    return str(v, f === 'description' ? 2000 : 500);
  };
  void isNum;
  route('GET', `/api/admin/${name}`, A, () => ({ items: db.prepare(`SELECT * FROM ${table} ORDER BY sort,id`).all() }));
  route('POST', `/api/admin/${name}`, A, ({ body }) => {
    for (const r of required) if (!String(body[r] ?? '').trim()) fail(400, `فیلد ${r} الزامی است`);
    const cols = fields.filter((f) => body[f] !== undefined && body[f] !== null);
    const id = db
      .prepare(`INSERT INTO ${table}(${cols.join(',')}) VALUES(${cols.map(() => '?').join(',')})`)
      .run(...cols.map((c) => clean(c, body[c]))).lastInsertRowid;
    return { item: db.prepare(`SELECT * FROM ${table} WHERE id=?`).get(id) };
  });
  route('PUT', `/api/admin/${name}/:id`, A, ({ params, body }) => {
    const cols = fields.filter((f) => body[f] !== undefined);
    for (const r of required) if (body[r] !== undefined && !String(body[r]).trim()) fail(400, `فیلد ${r} الزامی است`);
    if (cols.length) {
      db.prepare(`UPDATE ${table} SET ${cols.map((c) => c + '=?').join(',')} WHERE id=?`).run(
        ...cols.map((c) => clean(c, body[c])),
        params.id
      );
    }
    const item = db.prepare(`SELECT * FROM ${table} WHERE id=?`).get(params.id);
    if (!item) fail(404, 'یافت نشد');
    return { item };
  });
  route('DELETE', `/api/admin/${name}/:id`, A, ({ params }) => {
    db.prepare(`DELETE FROM ${table} WHERE id=?`).run(params.id);
    return { ok: true };
  });
}
crud('categories', 'categories', ['title', 'icon', 'sort', 'active'], ['title']);
crud('services', 'services', ['category_id', 'title', 'description', 'icon', 'image', 'price', 'sort', 'active'], ['title']);
crud('banners', 'banners', ['title', 'image', 'link', 'sort', 'active'], ['image']);
crud('socials', 'socials', ['platform', 'url', 'sort'], ['platform', 'url']);

// ---- settings
route('GET', '/api/admin/settings', A, () => {
  const s = getSettings();
  const tokenSet = !!s.sms_token;
  s.sms_token = '';
  s.sms_token_set = tokenSet ? '1' : '0';
  return { settings: s };
});

route('PUT', '/api/admin/settings', A, ({ body }) => {
  const allowed = Object.keys(getSettings());
  const up = db.prepare('INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value');
  transaction(() => {
    for (const [k, v] of Object.entries(body || {})) {
      if (!allowed.includes(k)) continue;
      if (k === 'sms_token' && !String(v ?? '').trim()) continue; // blank = keep existing token
      up.run(k, String(v ?? '').slice(0, 2000));
    }
  });
  return { ok: true };
});

route('POST', '/api/admin/sms/test', A, async ({ body }) => {
  const phone = normalizePhone(faDigits(body.phone));
  if (!phone) fail(400, 'شماره معتبر نیست');
  const s = getSettings();
  if (!s.sms_token) fail(400, 'ابتدا توکن ippanel را ذخیره کنید');
  try {
    const r = await sendViaIppanel(phone, '12345', s);
    return { ok: true, response: r.slice(0, 300) };
  } catch (e) {
    fail(502, e.message);
  }
});

route('PUT', '/api/admin/account', A, ({ admin, body }) => {
  const a = db.prepare('SELECT * FROM admins WHERE id=?').get(admin.id);
  if (!verifyPassword(body.current_password || '', a.password_hash)) fail(400, 'رمز فعلی اشتباه است');
  if (body.new_password) {
    if (String(body.new_password).length < 8) fail(400, 'رمز جدید حداقل ۸ کاراکتر باشد');
    db.prepare('UPDATE admins SET password_hash=? WHERE id=?').run(hashPassword(body.new_password), a.id);
  }
  if (body.new_email) {
    try {
      db.prepare('UPDATE admins SET email=? WHERE id=?').run(String(body.new_email).trim().toLowerCase(), a.id);
    } catch (_) {
      fail(400, 'این ایمیل قابل استفاده نیست');
    }
  }
  return { ok: true };
});

// ---- notifications
route('GET', '/api/admin/notifications', A, () => ({
  items: db.prepare('SELECT * FROM notifications ORDER BY id DESC LIMIT 200').all(),
}));
route('POST', '/api/admin/notifications', A, ({ body }) => {
  if (!String(body.title || '').trim()) fail(400, 'عنوان لازم است');
  const id = db
    .prepare('INSERT INTO notifications(title,body,image,link) VALUES(?,?,?,?)')
    .run(str(body.title, 200), str(body.body, 2000), str(body.image, 500), str(body.link, 500)).lastInsertRowid;
  return { item: db.prepare('SELECT * FROM notifications WHERE id=?').get(id) };
});
route('DELETE', '/api/admin/notifications/:id', A, ({ params }) => {
  db.prepare('DELETE FROM notifications WHERE id=?').run(params.id);
  return { ok: true };
});

// ---- image upload (JSON: { filename, data: <base64> })
function sniffImage(buf) {
  if (buf.length > 12 && buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) return 'png';
  if (buf.length > 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'jpg';
  if (buf.length > 6 && buf.toString('ascii', 0, 4) === 'GIF8') return 'gif';
  if (buf.length > 12 && buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') return 'webp';
  return null;
}
route('POST', '/api/admin/upload', { auth: 'admin', limit: 8 * 1024 * 1024 }, ({ body }) => {
  const buf = Buffer.from(String(body.data || ''), 'base64');
  if (!buf.length) fail(400, 'فایلی ارسال نشد');
  if (buf.length > 5 * 1024 * 1024) fail(413, 'حداکثر حجم تصویر ۵ مگابایت است');
  const ext = sniffImage(buf);
  if (!ext) fail(400, 'فقط تصویر png / jpg / webp / gif مجاز است');
  const name = crypto.randomBytes(12).toString('hex') + '.' + ext;
  fs.writeFileSync(path.join(DATA_DIR, 'uploads', name), buf);
  return { url: '/uploads/' + name };
});

// ================================================================ START
const PORT = process.env.PORT || 3000;
if (require.main === module) {
  server.listen(PORT, () => console.log(`Code Offer API listening on :${PORT}`));
}
module.exports = { server };
