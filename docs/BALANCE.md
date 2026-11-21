# 게임 수치 편집 안내

영광의 대관과 공통 전투는 각자 다른 리소스를 읽습니다. Godot 파일 시스템에서 아래 `.tres`를 열고 Inspector에서 값을 바꾸면 다음 경기부터 적용됩니다. 텍스트 편집 시에도 두 파일에 같은 필드가 있습니다. 단위는 초, 월드 픽셀, 정수 철혈입니다. 비율 0.5는 50%이고 배율 1.25는 기존 값의 125%입니다.

## 영광의 대관

`data/coronation_rules.tres`가 경기 전용 수치의 기준입니다.

| Inspector 그룹 | 편집 항목 |
|---|---|
| Match and zone | 경기 길이 `match_seconds`, 정사각형 맵 한 변 `map_side`, 세 번 수축의 시작 `shrink_starts`·종료 `shrink_ends`·목표 반경 `shrink_radii`, 장외 피해 주기·최대 HP 비율, AI가 미리 이동하는 경계 여유 |
| Tournament | 대진 칸 크기·간격, 대진 제한 시간, 라운드·결승 후 대기, 시작 간격·보호, 전투 피해 배율·후반 추가 배율·추가 배율이 시작되는 경기 진행률 |
| Iron points | 처치 기본점, 어시스트 상한 비율·집계 시간, 우승 보너스, 일반·강화 배회 몬스터와 필드 몬스터 점수 |
| Growth and bonuses | 기본 성장·경험치존에서 한 레벨에 해당하는 초, 처치·몬스터 종류별 한 레벨 대비 XP, 몬스터 처치 회복, 가속·둔화 시간과 이동 배율 |
| Field and spawning | 경험치존·필드 반경, 지점 배치 변화 폭과 중앙 여유, 배회 거리·리시 반경·강화 생성 확률, 몬스터 리스폰, 파괴물 수·보충 주기·HP·XP, 장식 밀도, 스폰 탐색 횟수·이격 거리·보호 시간, AI 이동 목표 교체 주기 |

기본 수축은 **1:35~2:00 / 2:35~3:00 / 3:35~4:00**입니다. 각 수축 종료와 다음 시작 사이에는 같은 크기를 유지합니다. 세 시작·종료 시간을 순서대로 배치하세요. 마지막 수축 종료 시 토너먼트를 시작하므로 경기 종료까지 여러 라운드와 재개 이후에 쓸 시간을 남겨두세요. 대진 공간이 목표 반경보다 넓으면 참가 칸이 원 안에 들어오도록 반경을 확보합니다.

토너먼트에서는 같은 라운드의 1대1을 동시에 진행합니다. 제한 시간 종료 시 **남은 체력 비율 → 실제 피해량 → 섞인 대진 순서**로 판정하고, 홀수 참가자는 한 명 부전승합니다. 자연 체력 회복은 중앙전 동안 정지합니다. 평상시에는 원래 설정된 체력 회복을 사용합니다. 파괴물용 벡터는 **수정·나무·버섯 순서**입니다.

철혈 어시스트는 `floor(처치 점수 × 어시스트 상한 비율 × 본인 유효 피해 / 모든 공격자의 유효 피해 합계)`입니다. 유효 피해는 집계 시간 안에 실제로 줄인 체력입니다. 과잉 피해, 완전 방어, 만료된 타격은 빠집니다. 피해만 주고 처치가 일어나지 않으면 점수가 새로 발생하지 않습니다.

## 공통 전투, 캐릭터와 성장

| 조정할 것 | 편집 위치 |
|---|---|
| 최고 레벨, 시작·최종 HP, 레벨업 회복, XP 곡선 | `data/balance.tres`의 Base growth 및 Experience and movement. 곡선은 `floor(xp_base + 레벨 × xp_linear + 레벨^xp_exponent × xp_curve)` |
| 기력, 탈진, 가드, 패링, 그로기, 평시 회복, 기본 공격 사거리·공격각 | `data/balance.tres`의 Groggy, Stamina, Guard timing, Combat |
| 걸음/달리기·공격/가드 이동 배율, 대시 시간·속도·무적·쿨타임, 치명타, 넉백, 명중 XP | `data/balance.tres`의 Experience and movement. 기본 걷기 속도와 공격력은 캐릭터 씬 루트의 `speed`·`damage` |
| AI 시야·타깃 갱신, 후퇴 체력·지속·재사용, 플레이어 상대 반응 시간·방어 간격·판단 창 | `data/balance.tres`의 AI behavior. 사거리 여유, 직업별 유지 거리, 스킬 사용 조건은 `scripts/fighter.gd`와 해당 직업 스크립트의 AI 함수 |
| 진화 계보·레벨, 스탯 보정, 평타 쿨타임·최대 타깃 수 | `data/characters/roster.tres`와 `data/characters/<직업>.tres`의 `unlock_level`, `parent_ids`, `multipliers`, `additions`, `attack_cooldown`, `attack_target_limit` |
| 기본·직업별 공격 판정, 선딜·후딜 | `scenes/characters/*.tscn`의 AnimationPlayer `swing` 길이·타격 메서드 키프레임과 루트의 공격 사거리·각도. 리소스에 공격 애니메이션을 지정하면 해당 리소스도 확인 |
| 검사 E, 창병 E, 망치병 차징·회복, 방패병 E·방패 | 각각 `scenes/characters/<직업>.tscn` 루트 Inspector의 직업별 변수. 방패 게이지·재생은 방패병 씬의 Guard 노드 |
| 후속 E/R/Q의 위력·범위·투사체 수·산탄각·비행 속도·수명·관통·회복·이동·무적·쿨타임 | `data/abilities/*.tres` 및 거기에 연결된 Animation의 발동 키 |
| 자유 스탯당 투자 효과·최대 랭크·AI 빌드 비중 | `scripts/stat_builds.gd` 상단 `INVESTMENT`, `MAX_RANK`, `PROFILES`. UI의 스탯 이름은 `STAT_INFO` |
| 몬스터 HP·속도·명중 반경·선공 거리·피해·공격 간격·복귀 회복 | `scenes/monster.tscn` 루트 Inspector. 영광의 대관 배치·보상은 대관 규칙 리소스 |
| 캐릭터·몬스터 수, 개발용 1대1 맵·시작 레벨·스폰 간격, 부활 가격, 레벨업·처치 골드, 이전 보스 시간 | `data/balance.tres`의 Arena 및 Legacy arena and economy. `monster_count`는 기존 아레나에 적용하며 대관의 거점·파괴물은 대관 규칙에서 조정 |
| 상점 가격·룬 최대 레벨·장착 수·룬 효과·시작 골드 | `scripts/meta.gd` 상단. 룬 이름·설명과 이전 방식의 성장 테이블은 `scripts/catalog.gd` |
| 이식용 이전 아레나의 고정 거점·보스 보정 및 보상 | `scenes/main.tscn`의 Zones와 `scripts/arena.gd`의 `start_boss`·`finish_boss`. 기본 메뉴의 대관에서는 이 보스를 시작하지 않음 |
| HUD와 터치 배치, 카메라, 색·폰트·음량·이펙트 | `scenes/ui.tscn`, `scripts/ui.gd`, `scripts/touch_controls.gd`, `scenes/main.tscn`, `scripts/arena.gd`. 경기 밸런스 리소스와 별도로 편집 |

수치를 수정한 뒤 `godot --headless --path . res://tests/coronation.tscn`으로 대관의 단계, 대진 충돌 격리, 철혈 정산을 검증합니다. 기본 수치를 의도적으로 바꾸면 고정 기본값을 비교하는 검사도 해당 기획값에 맞춰 갱신합니다.

