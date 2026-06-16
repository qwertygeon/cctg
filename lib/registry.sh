# lib/registry.sh — 예약/디렉터리 가드·레지스트리 조작·조회
# cc-tg.sh 가 런타임 source 하는 모듈(정의·전역설정 전용). 직접 실행하지 않는다.

# 예약 이름(전역 채널) 여부
is_reserved_name() { case " $RESERVED_NAMES " in *" $1 "*) return 0;; *) return 1;; esac; }

# 경로가 전역 채널 디렉터리($CHANNELS_DIR/<reserved>)인지 — purge 보호용
is_reserved_channel_dir() {
  local d
  for d in $RESERVED_NAMES; do [ "$1" = "$CHANNELS_DIR/$d" ] && return 0; done
  return 1
}

# 레지스트리에서 name 줄 제거 (주석·빈 줄은 보존)
remove_registry_line() {
  local name="$1" tmp
  tmp="$(mktemp)" || return 1
  awk -F'|' -v n="$name" '
    /^[[:space:]]*#/ {print; next}
    /^[[:space:]]*$/ {print; next}
    { c1=$1; gsub(/^[ \t]+|[ \t]+$/,"",c1); if (c1==n) next; print }
  ' "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
}

# 레지스트리에서 name 줄의 1번 컬럼(이름)·3번 컬럼(상태 디렉터리)을 갱신.
# working_dir(2번 컬럼)는 보존한다. 주석·빈 줄도 보존.
rename_registry_line() {
  local old="$1" new="$2" newsd="$3" tmp
  tmp="$(mktemp)" || return 1
  awk -F'|' -v o="$old" -v nn="$new" -v ns="$newsd" -v dc="$DEFAULT_CHANNEL" '
    /^[[:space:]]*#/ {print; next}
    /^[[:space:]]*$/ {print; next}
    {
      c1=$1; gsub(/^[ \t]+|[ \t]+$/,"",c1)
      if (c1==o) {
        c2=$2; gsub(/^[ \t]+|[ \t]+$/,"",c2)
        c4=$4; gsub(/^[ \t]+|[ \t]+$/,"",c4); if (c4=="") c4=dc
        printf "%s | %s | %s | %s\n", nn, c2, ns, c4
        next
      }
      print
    }
  ' "$REGISTRY" > "$tmp" && mv "$tmp" "$REGISTRY"
}

# 선행 ~ 확장
expand() { case "$1" in "~"*) printf '%s' "${HOME}${1#\~}";; *) printf '%s' "$1";; esac; }

# 레지스트리에서 name으로 한 줄 찾기 → "cwd<TAB>statedir"
lookup() {
  awk -F'|' -v n="$1" '
    /^[[:space:]]*#/ {next} /^[[:space:]]*$/ {next}
    { gsub(/^[ \t]+|[ \t]+$/,"",$1); gsub(/^[ \t]+|[ \t]+$/,"",$2); gsub(/^[ \t]+|[ \t]+$/,"",$3);
      if ($1==n) { print $2 "\t" $3; found=1 } }
    END { if (!found) exit 1 }
  ' "$REGISTRY"
}

# 모든 등록된 name 출력
all_names() {
  awk -F'|' '/^[[:space:]]*#/{next} /^[[:space:]]*$/{next} {gsub(/^[ \t]+|[ \t]+$/,"",$1); print $1}' "$REGISTRY"
}
