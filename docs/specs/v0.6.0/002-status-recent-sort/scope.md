# Scope — v0.6.0/002 status 최근 실행순 정렬

의도적 스코프 컷(no-silent-caps). 형식: CUT-XXX.

- **CUT-001**: `status --json`(`status_json`) 출력 배열 순서는 변경하지 않는다 (기존 `all_names`
  등록 순서 유지).
  - 사유: 사용자 요구는 사람용 `cctg status` 표시("나오는 항목") 한정이다. `--json` 은
    기계 판독용이며 소비자가 자체 정렬하므로 배열 순서 의미가 약하고, 순서 변경 시 기존
    소비자에 예기치 않은 영향을 줄 수 있다.
  - 재포함 조건: 사용자가 `--json` 에도 최근순 적용을 원하면 `_sort_bucket_by_created` 를
    동일하게 재사용해 추가 가능(저비용).
