# lib/config.sh — key=value·launch.env 헬퍼
# cc-tg.sh 가 런타임 source 하는 모듈(정의·전역설정 전용). 직접 실행하지 않는다.

# key=value 설정 파일에서 키 값을 읽는다(마지막 매치, '=' 뒤 전체). 없거나 빈 값이면 빈 문자열.
conf_get() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 0
  awk -F= -v k="$key" '$1==k{v=substr($0,index($0,"=")+1)} END{if(v!="")print v}' "$file"
}

# key=value 설정 파일에 키를 upsert(있으면 치환, 없으면 추가). 디렉터리/파일 없으면 생성.
conf_set() {
  local file="$1" key="$2" val="$3" tmp
  mkdir -p "$(dirname "$file")"
  [ -f "$file" ] || : > "$file"
  tmp="$(mktemp)" || return 1
  if grep -qE "^${key}=" "$file" 2>/dev/null; then
    awk -F= -v k="$key" -v v="$val" '$1==k{print k"="v;next}{print}' "$file" > "$tmp" && mv "$tmp" "$file"
  else
    cp "$file" "$tmp" && printf '%s=%s\n' "$key" "$val" >> "$tmp" && mv "$tmp" "$file"
  fi
}

# key=value 설정 파일에서 키 제거. 파일 없으면 무동작.
conf_unset() {
  local file="$1" key="$2" tmp
  [ -f "$file" ] || return 0
  tmp="$(mktemp)" || return 1
  awk -F= -v k="$key" '$1==k{next}{print}' "$file" > "$tmp" && mv "$tmp" "$file"
}
# launch.env 에 KEY="value" upsert (있으면 치환, 없으면 추가). 값은 그대로 기록(셸 치환 주의는 호출측 책임).
set_env_kv() {
  local file="$1" key="$2" val="$3" tmp
  [ -f "$file" ] || : > "$file"
  tmp="$(mktemp)" || return 1
  if grep -qE "^${key}=" "$file" 2>/dev/null; then
    awk -v k="$key" -v v="$val" '$0 ~ "^"k"=" { print k"=\""v"\""; next } { print }' "$file" > "$tmp" && mv "$tmp" "$file"
  else
    cp "$file" "$tmp" && printf '%s="%s"\n' "$key" "$val" >> "$tmp" && mv "$tmp" "$file"
  fi
}

# launch.env 에서 CCTG_PERMISSION_MODE 값만 추출(따옴표 제거). 없으면 빈 문자열.
mode_of() {
  conf_get "$1/launch.env" CCTG_PERMISSION_MODE \
    | sed -E 's/^"//; s/"$//; s/^'\''//; s/'\''$//'
}

# launch.env 의 CCTG_LOG_SNAPSHOT_INTERVAL(초) 추출(따옴표 제거). 없으면 빈 문자열.
snapshot_interval_of() {
  conf_get "$1/launch.env" CCTG_LOG_SNAPSHOT_INTERVAL \
    | sed -E 's/^"//; s/"$//; s/^'\''//; s/'\''$//'
}
