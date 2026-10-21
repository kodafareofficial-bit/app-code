#!/usr/bin/env bash
# دانلود فونت Vazirmatn برای اپ. اگر دانلود نشد، فونت از pubspec حذف می‌شود تا بیلد خراب نشود (فونت سیستم استفاده می‌شود).
set -u
cd "$(dirname "$0")/.."
mkdir -p assets/fonts
need=(Regular Medium Bold)

have_all() {
  for w in "${need[@]}"; do [ -s "assets/fonts/Vazirmatn-$w.ttf" ] || return 1; done
}

if have_all; then
  echo "Vazirmatn fonts already present."
  exit 0
fi

bases=(
  "https://cdn.jsdelivr.net/npm/vazirmatn@33.0.3/fonts/ttf"
  "https://unpkg.com/vazirmatn@33.0.3/fonts/ttf"
  "https://raw.githubusercontent.com/rastikerdar/vazirmatn/v33.003/fonts/ttf"
)
for base in "${bases[@]}"; do
  ok=1
  for w in "${need[@]}"; do
    curl -fsSL --retry 2 --max-time 60 "$base/Vazirmatn-$w.ttf" -o "assets/fonts/Vazirmatn-$w.ttf" || ok=0
  done
  if [ "$ok" = 1 ] && have_all; then
    echo "Fonts downloaded from $base"
    exit 0
  fi
done

echo "::warning::Vazirmatn font download failed; building with the system font. Put Vazirmatn-{Regular,Medium,Bold}.ttf in assets/fonts to fix."
rm -f assets/fonts/*.ttf
python3 - <<'PY'
import re, pathlib
p = pathlib.Path('pubspec.yaml')
s = p.read_text(encoding='utf-8')
s2 = re.sub(r"\n  fonts:\n(?:    .*\n|      .*\n|        .*\n)+", "\n", s)
p.write_text(s2, encoding='utf-8')
print("fonts section removed from pubspec" if s2 != s else "no fonts section found")
PY
exit 0
