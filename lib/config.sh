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
# 토큰 .env 를 원자적으로 작성(`KEY=value` 단일 행). 같은 디렉터리의 임시 파일에 쓰고 mv 로 교체해
# 부분/빈 파일이 남지 않게 한다(`>` 직접 쓰기는 truncate 후 중단 시 토큰이 깨진다). mktemp 가 0600 으로
# 생성하므로 world-readable 창이 없다. 성공 0 / 실패 비0(호출측이 die 처리). [P-003 / TODO 비원자적 쓰기]
write_token_env() {
  local file="$1" key="$2" val="$3" tmp
  tmp="$(mktemp "${file%/*}/.env.XXXXXX")" || return 1
  printf '%s=%s\n' "$key" "$val" > "$tmp" || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$file" || { rm -f "$tmp"; return 1; }
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

# launch.env 의 CCTG_SESS_WIDTH(칼럼) 추출(따옴표 제거). 없으면 빈 문자열.
sess_width_of() {
  conf_get "$1/launch.env" CCTG_SESS_WIDTH \
    | sed -E 's/^"//; s/"$//; s/^'\''//; s/'\''$//'
}

# 봇의 유효 detached 폭 해석. $1=상태 디렉터리.
# 우선순위: 봇별(launch.env CCTG_SESS_WIDTH) > env(CC_TG_SESS_WIDTH)
#           > 전역(CCTG_CONFIG sess_width = `cctg common width`) > SESS_WIDTH_DEFAULT(100).
# 각 후보는 valid_width(양의 정수 ∧ >=20)를 통과해야 채택, 아니면 다음 후보로 폴백한다.
# (env>config 우선순위는 lang 해석 CCTG_LANG>config 와 동형. valid_width 는 util.sh,
#  호출 시점엔 모든 모듈이 source 돼 있다.)
effective_sess_width() {
  local sd="$1" w
  w="$(sess_width_of "$sd")";              valid_width "$w" && { printf '%s' "$w"; return; }
  w="${CC_TG_SESS_WIDTH:-}";               valid_width "$w" && { printf '%s' "$w"; return; }
  w="$(conf_get "$CCTG_CONFIG" sess_width)"; valid_width "$w" && { printf '%s' "$w"; return; }
  printf '%s' "$SESS_WIDTH_DEFAULT"
}
