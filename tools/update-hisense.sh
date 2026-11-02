#!/usr/bin/env bash
# Updates Free My TV on the Hisense: pulls the latest code, optionally saves your TMDB key (typed hidden, never printed),
# rebuilds and installs. Run it from Ubuntu:  bash ~/free-my-tv/tools/update-hisense.sh
set -euo pipefail
export ANDROID_HOME="${ANDROID_HOME:-$HOME/android}"
TV_IP="${TV_IP:-192.168.1.31}"
cd "$(dirname "$0")/.."

git pull --ff-only

# The greeting on the home screen ("Hello, Joshua!"). Change it in config.properties if you like.
grep -qE '^[[:space:]]*name[[:space:]]*=' config.properties 2>/dev/null || echo 'name=Joshua' >> config.properties

# Asks for the TMDB key (typed hidden), checks it against TMDB and keeps asking until it works or you skip.
check_key() { # prints the HTTP code TMDB answers, never the key
  if [[ "$1" == eyJ* ]]; then
    curl -s -o /dev/null -m 15 -w '%{http_code}' -H "Authorization: Bearer $1" https://api.themoviedb.org/3/configuration
  else
    curl -s -o /dev/null -m 15 -w '%{http_code}' "https://api.themoviedb.org/3/configuration?api_key=$1"
  fi
}
save_key() {
  if grep -qE '^[[:space:]]*tmdb_key[[:space:]]*=' config.properties; then
    sed -i -E "s|^[[:space:]]*tmdb_key[[:space:]]*=.*|tmdb_key=$1|" config.properties
  else
    echo "tmdb_key=$1" >> config.properties
  fi
}
CURRENT="$(grep -E '^[[:space:]]*tmdb_key[[:space:]]*=' config.properties 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '[:space:]"\\' || true)"
if [ -n "$CURRENT" ] && [ "$(check_key "$CURRENT")" = "200" ]; then
  echo "TMDB key OK."
else
  [ -n "$CURRENT" ] && echo "The saved TMDB key was rejected. Paste it again."
  echo "Get it at themoviedb.org > Settings > API (the long API Read Access Token, or the 32-character API Key)."
  while true; do
    read -r -s -p "TMDB key (Enter to skip): " KEY < /dev/tty || true; echo
    KEY="$(printf '%s' "$KEY" | tr -d '[:space:]"\\')"
    [ -z "$KEY" ] && { echo "Skipped: the cards will show the time, weather and sun."; break; }
    echo "Key length: ${#KEY}"
    CODE="$(check_key "$KEY")"
    if [ "$CODE" = "200" ]; then save_key "$KEY"; echo "Key accepted and saved in config.properties (it stays out of git)."; break; fi
    echo "TMDB answered $CODE: that is not a valid key. Check you copied all of it, then try again."
  done
  unset KEY
fi
unset CURRENT

./build.sh
adb connect "$TV_IP:5555" || true
adb -s "$TV_IP:5555" install -r FreeMyTV.apk
adb -s "$TV_IP:5555" shell am force-stop io.freemytv
echo "Done. On the TV press Home. To turn off the apps added in this update: Home Screen > Original, then Free My TV."
