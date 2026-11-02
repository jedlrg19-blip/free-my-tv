#!/usr/bin/env bash
# Updates Free My TV on the Hisense: pulls the latest code, optionally saves your TMDB key (typed hidden, never printed),
# rebuilds and installs. Run it from Ubuntu:  bash ~/free-my-tv/tools/update-hisense.sh
set -euo pipefail
export ANDROID_HOME="${ANDROID_HOME:-$HOME/android}"
TV_IP="${TV_IP:-192.168.1.31}"
cd "$(dirname "$0")/.."

git pull --ff-only

if ! grep -qE '^[[:space:]]*tmdb_key[[:space:]]*=[[:space:]]*[^[:space:]]' config.properties 2>/dev/null; then
  echo "No TMDB key yet. Create one (free) at themoviedb.org > Settings > API, then paste it here."
  echo "Typing is hidden. Press Enter on an empty line to skip (you can run this again later)."
  read -r -s -p "TMDB key: " KEY < /dev/tty || true; echo
  KEY="$(printf '%s' "$KEY" | tr -d '[:space:]"\\')"
  if [ -n "$KEY" ]; then
    if grep -qE '^[[:space:]]*tmdb_key[[:space:]]*=' config.properties; then
      sed -i -E "s|^[[:space:]]*tmdb_key[[:space:]]*=.*|tmdb_key=$KEY|" config.properties
    else
      echo "tmdb_key=$KEY" >> config.properties
    fi
    echo "Key saved in config.properties (it stays out of git)."
  fi
  unset KEY
fi

./build.sh
adb connect "$TV_IP:5555" || true
adb -s "$TV_IP:5555" install -r FreeMyTV.apk
adb -s "$TV_IP:5555" shell am force-stop io.freemytv
echo "Done. On the TV press Home. To turn off the apps added in this update: Home Screen > Original, then Free My TV."
