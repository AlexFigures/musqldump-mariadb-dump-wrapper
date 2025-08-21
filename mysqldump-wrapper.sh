#!/bin/sh
# mariadb-dump wrapper: add --skip-ssl by default, keep defaults-file first

set -eu
MARIADB_DUMP="${MARIADB_DUMP:-/usr/bin/mariadb-dump}"

add_skip_ssl=true
prefix=""   # сюда кладём --defaults-file / --defaults-extra-file (обяз. первые)
rest=""

append() {
  case "$1" in
    '') rest="$rest ''" ;;
    *)  rest="$rest '$(printf %s "$1" | sed "s/'/'\\\\''/g")'" ;;
  esac
}

append_prefix() {
  case "$1" in
    '') prefix="$prefix ''" ;;
    *)  prefix="$prefix '$(printf %s "$1" | sed "s/'/'\\\\''/g")'" ;;
  esac
}

warn() { printf '%s\n' "$*" >&2; }

while [ "$#" -gt 0 ]; do
  arg=$1; shift
  case "$arg" in
    --)
      append "$arg"
      while [ "$#" -gt 0 ]; do append "$1"; shift; done
      break
      ;;

    # ---- defaults-file / defaults-extra-file: держим первыми
    --defaults-file)
      path=${1-}; [ "$#" -gt 0 ] && shift || true
      if [ -n "${path:-}" ] && [ -e "$path" ]; then
        append_prefix "--defaults-file=$path"
      else
        warn "Ignoring --defaults-file: file not found: $path"
      fi
      ;;
    --defaults-file=*)
      path=${arg#--defaults-file=}
      if [ -e "$path" ]; then append_prefix "$arg"; else warn "Ignoring --defaults-file: file not found: $path"; fi
      ;;

    --defaults-extra-file)
      path=${1-}; [ "$#" -gt 0 ] && shift || true
      if [ -n "${path:-}" ] && [ -e "$path" ]; then
        append_prefix "--defaults-extra-file=$path"
      else
        warn "Ignoring --defaults-extra-file: file not found: $path"
      fi
      ;;
    --defaults-extra-file=*)
      path=${arg#--defaults-extra-file=}
      if [ -e "$path" ]; then append_prefix "$arg"; else warn "Ignoring --defaults-extra-file: file not found: $path"; fi
      ;;

    # ---- SSL-логика
    --skip-ssl)
      add_skip_ssl=false
      append "$arg"
      ;;
    --ssl|--ssl-verify-server-cert)
      add_skip_ssl=false
      append "$arg"
      ;;
    --ssl-ca|--ssl-cert|--ssl-key)
      add_skip_ssl=false
      append "$arg"
      if [ "$#" -gt 0 ]; then append "$1"; shift; fi
      ;;
    --ssl-ca=*|--ssl-cert=*|--ssl-key=*)
      add_skip_ssl=false
      append "$arg"
      ;;
    --ssl-mode)
      mode=${1-}; [ "$#" -gt 0 ] && shift || true
      case "$(printf %s "$mode" | tr '[:lower:]' '[:upper:]')" in
        DISABLED) add_skip_ssl=true  ;;
        *)        add_skip_ssl=false ;;
      esac
      ;;
    --ssl-mode=*)
      val=${arg#--ssl-mode=}
      case "$(printf %s "$val" | tr '[:lower:]' '[:upper:]')" in
        DISABLED) add_skip_ssl=true  ;;
        *)        add_skip_ssl=false ;;
      esac
      ;;

    # ---- несовместимые с mariadb-dump — выбрасываем
    --set-gtid-purged|--column-statistics)
      # проглотить возможное значение в двухаргументной форме
      if [ "$#" -gt 0 ] && [ "${1#-}" = "$1" ]; then shift; fi
      ;;
    --set-gtid-purged=*|--column-statistics=*)
      ;;

    # ---- всё остальное — как есть
    *)
      append "$arg"
      ;;
  esac
done

# Собираем финальный argv: [defaults* first] [--skip-ssl?] [rest]
final="$prefix"
if [ "$add_skip_ssl" = true ]; then final="$final '--skip-ssl'"; fi
final="$final $rest"

# shellcheck disable=SC2086
eval "set -- $final"
exec "$MARIADB_DUMP" "$@"
