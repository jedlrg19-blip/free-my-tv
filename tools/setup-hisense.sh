#!/usr/bin/env bash
# Sets up everything to build and install Free My TV on a Hisense HiSmartTV A4, from Ubuntu (WSL).
# Safe to run again: it only installs what is missing. It never changes modes on the TV: you do that on the TV.
set -euo pipefail

TV_IP="${TV_IP:-192.168.1.31}"
BRANCH="claude/optimistic-johnson-4v4zfj"
REPO="https://github.com/jedlrg19-blip/free-my-tv"
DIR="$HOME/free-my-tv"
export ANDROID_HOME="$HOME/android"

say() { printf '\n== %s\n' "$*"; }
ask() { local v; read -r -p "$1 [$2]: " v < /dev/tty || true; printf '%s' "${v:-$2}"; }

say "1/5 Tools (Ubuntu will ask for your password)"
sudo apt-get update -q
sudo apt-get install -y -q openjdk-17-jdk adb unzip curl git zip

say "2/5 Android SDK"
if [ ! -d "$ANDROID_HOME/build-tools/34.0.0" ] || [ ! -d "$ANDROID_HOME/platforms/android-34" ]; then
  mkdir -p "$ANDROID_HOME/cmdline-tools" && cd "$ANDROID_HOME/cmdline-tools"
  if [ ! -d latest ]; then
    curl -fLO https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
    unzip -q commandlinetools-linux-11076708_latest.zip && mv cmdline-tools latest && rm commandlinetools-linux-11076708_latest.zip
  fi
  yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null || true
  "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "build-tools;34.0.0" "platforms;android-34"
fi
grep -q 'ANDROID_HOME=' "$HOME/.bashrc" || echo 'export ANDROID_HOME=$HOME/android' >> "$HOME/.bashrc"

say "3/5 Code"
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" fetch origin "$BRANCH" && git -C "$DIR" checkout "$BRANCH" && git -C "$DIR" pull --ff-only origin "$BRANCH"
else
  git clone -b "$BRANCH" "$REPO" "$DIR"
fi
cd "$DIR"

say "4/5 Your settings (Enter keeps the value in brackets)"
if [ ! -f config.properties ]; then cp config.example.properties config.properties; fi
setp() { # key value: replaces the line, or adds it
  if grep -qE "^[[:space:]]*$1[[:space:]]*=" config.properties; then
    sed -i -E "s|^[[:space:]]*$1[[:space:]]*=.*|$1=$2|" config.properties
  else echo "$1=$2" >> config.properties; fi
}
setp city "$(ask 'City name' 'Mexico City')"
setp latitude "$(ask 'Latitude (Google Maps, e.g. 19.4326)' '19.4326')"
setp longitude "$(ask 'Longitude (e.g. -99.1332)' '-99.1332')"
setp tmdb_region "$(ask 'Country, 2 letters (MX, PE, ES...)' 'MX')"
setp language "$(ask 'Language (es, pt, en)' 'es')"
echo "The TMDB key is optional and yours: open config.properties and paste it after tmdb_key= if you want the picks."

./build.sh

say "5/5 Install on the TV at $TV_IP"
echo "On the TV: Settings > Device Preferences > Developer options > USB debugging must be ON."
read -r -p "Press Enter to connect (then ACCEPT the prompt on the TV, tick 'Always allow')..." _ < /dev/tty || true
adb start-server >/dev/null 2>&1 || true
adb connect "$TV_IP:5555"
read -r -p "Did you accept the prompt on the TV? Press Enter to install..." _ < /dev/tty || true
adb -s "$TV_IP:5555" install -r FreeMyTV.apk

cat <<MSG

Done. Now, on the TV with the remote: Free My TV > Home Screen > Free My TV (accept the debugging prompt again).
To go back any time: Home Screen > Original.
To see what it did: adb logcat -s FreeMyTV
MSG
