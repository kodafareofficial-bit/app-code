const { DatabaseSync } = require('node:sqlite');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');

const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, '..', 'data');
fs.mkdirSync(path.join(DATA_DIR, 'uploads'), { recursive: true });

const db = new DatabaseSync(path.join(DATA_DIR, 'codeoffer.db'));
db.exec('PRAGMA journal_mode = WAL; PRAGMA foreign_keys = ON;');

db.exec(`
CREATE TABLE IF NOT EXISTS admins (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  phone TEXT UNIQUE NOT NULL,
  name TEXT DEFAULT '',
  email TEXT DEFAULT '',
  city TEXT DEFAULT '',
  bio TEXT DEFAULT '',
  blocked INTEGER DEFAULT 0,
  notif_enabled INTEGER DEFAULT 1,
  created_at TEXT DEFAULT (datetime('now')),
  last_login TEXT
);
CREATE TABLE IF NOT EXISTS otps (
  phone TEXT PRIMARY KEY,
  code_hash TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  attempts INTEGER DEFAULT 0,
  last_sent INTEGER DEFAULT 0
);
CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  icon TEXT DEFAULT 'apps',
  sort INTEGER DEFAULT 0,
  active INTEGER DEFAULT 1
);
CREATE TABLE IF NOT EXISTS services (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  category_id INTEGER,
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  icon TEXT DEFAULT 'code',
  image TEXT DEFAULT '',
  price TEXT DEFAULT '',
  sort INTEGER DEFAULT 0,
  active INTEGER DEFAULT 1
);
CREATE TABLE IF NOT EXISTS banners (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT DEFAULT '',
  image TEXT NOT NULL,
  link TEXT DEFAULT '',
  sort INTEGER DEFAULT 0,
  active INTEGER DEFAULT 1
);
CREATE TABLE IF NOT EXISTS socials (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  platform TEXT NOT NULL,
  url TEXT NOT NULL,
  sort INTEGER DEFAULT 0
);
CREATE TABLE IF NOT EXISTS notifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT NOT NULL,
  body TEXT DEFAULT '',
  image TEXT DEFAULT '',
  link TEXT DEFAULT '',
  created_at TEXT DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT DEFAULT ''
);
`);

const DEFAULT_SETTINGS = {
  company_name: 'کد آفر',
  company_name_en: 'Code Offer',
  tagline: 'راهکارهای نرم‌افزاری حرفه‌ای',
  about: 'کد آفر ارائه‌دهنده خدمات طراحی و توسعه نرم‌افزار، اپلیکیشن و وب‌سایت است.',
  logo: '',
  primary_color: '#6C4DFF',
  accent_color: '#00C2A8',
  splash_color: '#0F0B2E',
  splash_text: 'به کد آفر خوش آمدید',
  support_phone: '',
  support_email: '',
  // ippanel Edge API -> POST {base_url}/api/send
  sms_enabled: '0',
  sms_base_url: 'https://edge.ippanel.com/v1',
  sms_token: '',
  sms_from_number: '+983000505',
  sms_mode: 'pattern', // pattern | webservice
  sms_pattern_code: '',
  sms_pattern_param: 'code',
  sms_message_template: 'کد تایید شما در کد آفر: {code}',
};
const insSetting = db.prepare('INSERT OR IGNORE INTO settings(key,value) VALUES(?,?)');
for (const [k, v] of Object.entries(DEFAULT_SETTINGS)) insSetting.run(k, v);

// ---- password hashing (scrypt) ----
function hashPassword(pw) {
  const salt = crypto.randomBytes(16).toString('hex');
  const h = crypto.scryptSync(String(pw), salt, 64).toString('hex');
  return `scrypt$${salt}$${h}`;
}
function verifyPassword(pw, stored) {
  const [alg, salt, h] = String(stored).split('$');
  if (alg !== 'scrypt' || !salt || !h) return false;
  const calc = crypto.scryptSync(String(pw), salt, 64);
  const exp = Buffer.from(h, 'hex');
  return exp.length === calc.length && crypto.timingSafeEqual(calc, exp);
}

// ---- fixed admin (from environment; re-synced on each boot) ----
const ADMIN_EMAIL = (process.env.ADMIN_EMAIL || 'admin@codeoffer.ir').trim().toLowerCase();
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'ChangeMe#123';
if (!process.env.ADMIN_PASSWORD) {
  console.warn('[WARN] ADMIN_PASSWORD is not set; using the insecure default "ChangeMe#123". Set it in your environment!');
}
const ex = db.prepare('SELECT id FROM admins WHERE email=?').get(ADMIN_EMAIL);
if (ex) {
  db.prepare('UPDATE admins SET password_hash=? WHERE id=?').run(hashPassword(ADMIN_PASSWORD), ex.id);
} else {
  db.exec('DELETE FROM admins');
  db.prepare('INSERT INTO admins(email,password_hash) VALUES(?,?)').run(ADMIN_EMAIL, hashPassword(ADMIN_PASSWORD));
}

// ---- demo content (first run only) ----
if (db.prepare('SELECT COUNT(*) c FROM categories').get().c === 0) {
  const ci = db.prepare('INSERT INTO categories(title,icon,sort) VALUES(?,?,?)');
  const c1 = ci.run('طراحی اپلیکیشن', 'phone_android', 1).lastInsertRowid;
  const c2 = ci.run('طراحی وب‌سایت', 'language', 2).lastInsertRowid;
  const c3 = ci.run('خدمات پشتیبانی', 'support_agent', 3).lastInsertRowid;
  const s = db.prepare('INSERT INTO services(category_id,title,description,icon,price,sort) VALUES(?,?,?,?,?,?)');
  s.run(c1, 'اپلیکیشن اندروید و iOS', 'توسعه اپلیکیشن با فلاتر؛ سریع، مدرن و قابل توسعه', 'phone_android', 'تماس بگیرید', 1);
  s.run(c2, 'وب‌سایت شرکتی', 'طراحی سایت اختصاصی، ریسپانسیو و سئو شده', 'language', 'تماس بگیرید', 2);
  s.run(c3, 'پشتیبانی و نگهداری', 'پشتیبانی و به‌روزرسانی مداوم پروژه‌ها', 'support_agent', 'تماس بگیرید', 3);
}

function transaction(fn) {
  db.exec('BEGIN');
  try {
    const r = fn();
    db.exec('COMMIT');
    return r;
  } catch (e) {
    db.exec('ROLLBACK');
    throw e;
  }
}

module.exports = { db, DATA_DIR, DEFAULT_SETTINGS, hashPassword, verifyPassword, transaction };
