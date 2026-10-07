#!/usr/bin/env bash
# apkey — создаёт JKS-keystore для подписи Android-приложения и упаковывает
# его в signKeystore.zip в текущей папке.
# https://github.com/vazovsky17/apKey

set -euo pipefail

VERSION="1.0.0"
ZIP_NAME="signKeystore"

usage() {
  cat <<EOF
apkey $VERSION — generate an Android signing keystore (JKS) packed into $ZIP_NAME.zip

Usage:
  apkey [options] [file.jks] [alias]

Arguments:
  file.jks    keystore file name inside the archive (default: release.jks)
  alias       key alias (default: upload)

Options:
  -h, --help     show this help and exit
  -V, --version  show version and exit

The archive is created in the current directory and contains:
  $ZIP_NAME/<file>.jks, $ZIP_NAME/keystore.properties, $ZIP_NAME/fingerprints.txt
EOF
}

case "${1:-}" in
  -h|--help)    usage; exit 0 ;;
  -V|--version) echo "apkey $VERSION"; exit 0 ;;
  -*)           echo "Неизвестный параметр: $1" >&2; usage >&2; exit 2 ;;
esac

# --- Поиск keytool ---
find_keytool() {
  if command -v keytool >/dev/null 2>&1 && keytool -help >/dev/null 2>&1; then
    command -v keytool; return
  fi
  local candidates=(
    "${JAVA_HOME:-}/bin/keytool"
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool"
    "/Applications/Android Studio.app/Contents/jre/Contents/Home/bin/keytool"
    "$HOME/android-studio/jbr/bin/keytool"
    "/opt/android-studio/jbr/bin/keytool"
    "/snap/android-studio/current/jbr/bin/keytool"
  )
  if [[ -x /usr/libexec/java_home ]]; then
    local jh
    jh="$(/usr/libexec/java_home 2>/dev/null || true)"
    [[ -n "$jh" ]] && candidates=("$jh/bin/keytool" "${candidates[@]}")
  fi
  for k in "${candidates[@]}"; do
    [[ -x "$k" ]] && { echo "$k"; return; }
  done
  return 1
}

KEYTOOL="$(find_keytool)" || {
  echo "Ошибка: keytool не найден. Установите JDK или Android Studio." >&2
  exit 1
}

command -v zip >/dev/null 2>&1 || { echo "Ошибка: не найдена утилита zip." >&2; exit 1; }

OUT_DIR="$(pwd)"
ZIP_PATH="$OUT_DIR/$ZIP_NAME.zip"

if [[ -e "$ZIP_PATH" ]]; then
  echo "Ошибка: файл уже существует: $ZIP_PATH" >&2
  exit 1
fi

# --- Параметры ---
read -r -p "Имя файла keystore [${1:-release.jks}]: " FILE_NAME
FILE_NAME="${FILE_NAME:-${1:-release.jks}}"
[[ "$FILE_NAME" == *.jks ]] || FILE_NAME="$FILE_NAME.jks"
if [[ "$FILE_NAME" == */* ]]; then
  echo "Ошибка: имя файла не должно содержать '/'." >&2
  exit 1
fi

read -r -p "Alias ключа [${2:-upload}]: " KEY_ALIAS
KEY_ALIAS="${KEY_ALIAS:-${2:-upload}}"

read -r -p "Имя и фамилия (CN) [Android]: " CN;    CN="${CN:-Android}"
read -r -p "Организация (O) []: " ORG
read -r -p "Код страны (C, напр. RU) []: " COUNTRY

# --- Пароль (дважды) ---
while true; do
  read -r -s -p "Пароль (мин. 6 символов): " PASS1; echo
  if [[ ${#PASS1} -lt 6 ]]; then
    echo "Пароль слишком короткий, попробуйте ещё раз." >&2; continue
  fi
  read -r -s -p "Повторите пароль: " PASS2; echo
  if [[ "$PASS1" != "$PASS2" ]]; then
    echo "Пароли не совпадают, попробуйте ещё раз." >&2; continue
  fi
  break
done
unset PASS2

# Экранирование спецсимволов для Distinguished Name
dn_escape() { printf '%s' "$1" | sed 's/[\\,+"<>;=]/\\&/g'; }
DNAME="CN=$(dn_escape "$CN")"
[[ -n "$ORG" ]]     && DNAME="$DNAME, O=$(dn_escape "$ORG")"
[[ -n "$COUNTRY" ]] && DNAME="$DNAME, C=$(dn_escape "$COUNTRY")"

# Пароль передаётся через переменную окружения, чтобы не светиться в списке процессов
export JKS_PASS="$PASS1"
unset PASS1

# Временная папка для сборки архива
WORK_DIR="$(mktemp -d)"
trap 'unset JKS_PASS; rm -rf "$WORK_DIR"' EXIT
BUNDLE_DIR="$WORK_DIR/$ZIP_NAME"
mkdir -p "$BUNDLE_DIR"
JKS_PATH="$BUNDLE_DIR/$FILE_NAME"

"$KEYTOOL" -genkeypair \
  -keystore "$JKS_PATH" \
  -storetype JKS \
  -alias "$KEY_ALIAS" \
  -keyalg RSA -keysize 2048 \
  -validity 10000 \
  -dname "$DNAME" \
  -storepass:env JKS_PASS \
  -keypass:env JKS_PASS \
  -noprompt 2>&1 | grep -vE "^Warning:|proprietary format|pkcs12|^[[:space:]]*$" || true

if [[ ! -f "$JKS_PATH" ]]; then
  echo "Ошибка: keystore не создан." >&2
  exit 1
fi

# --- keystore.properties для Gradle ---
props_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g'; }
cat > "$BUNDLE_DIR/keystore.properties" <<EOF
storeFile=$FILE_NAME
storePassword=$(props_escape "$JKS_PASS")
keyAlias=$KEY_ALIAS
keyPassword=$(props_escape "$JKS_PASS")
EOF

# --- Отпечатки сертификата ---
FINGERPRINTS="$("$KEYTOOL" -list -v -keystore "$JKS_PATH" -alias "$KEY_ALIAS" -storepass:env JKS_PASS 2>/dev/null \
  | grep -E '^[[:space:]]*SHA(1|256):' | sed 's/^[[:space:]]*//' || true)"
{
  echo "Keystore: $FILE_NAME"
  echo "Alias:    $KEY_ALIAS"
  echo "DN:       $DNAME"
  echo
  echo "$FINGERPRINTS"
} > "$BUNDLE_DIR/fingerprints.txt"

# --- Архив ---
(umask 077 && cd "$WORK_DIR" && zip -qr "$ZIP_PATH" "$ZIP_NAME")

echo
echo "Готово: $ZIP_PATH"
echo "  $ZIP_NAME/$FILE_NAME"
echo "  $ZIP_NAME/keystore.properties"
echo "  $ZIP_NAME/fingerprints.txt"
echo
echo "$FINGERPRINTS"
