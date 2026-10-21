/// آدرس سرور (بک‌اند). هنگام بیلد با --dart-define=API_BASE_URL=... تنظیم می‌شود.
/// در GitHub Actions این مقدار از Variable به نام API_BASE_URL خوانده می‌شود.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000', // آدرس لوکال‌هاست در امولاتور اندروید
);

const int pollSeconds = 45;
