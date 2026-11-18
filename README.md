# IRON CROWN · Godot edition

[게임 실행](https://player149.github.io/iron-crown/) · [배포 현황](https://github.com/Player149/iron-crown/actions) · [검증 결과와 제한](docs/STATUS.md)

Godot 4.7.2 / GDScript / Compatibility 렌더러로 이식한 싱글플레이 아레나 게임입니다. 원본 HTML을 감싼 형태가 아니라 Godot 씬·노드·리소스·AnimationPlayer로 구성했습니다.

## 열기 / 편집

Godot 4.7.2에서 이 저장소의 `project.godot`을 가져온 뒤 실행(F6: 현재 씬, F5: 게임)합니다. Android Godot 에디터에서도 같은 폴더를 열 수 있습니다. PC와 모바일은 같은 파일 구조를 사용하며 Git으로 커밋·푸시·풀합니다. 기기 사이의 동기화는 자동 파일 복사가 아니라 Git 변경사항 동기화입니다.

| 편집할 내용 | 파일 / 에디터 위치 |
|---|---|
| 맵과 경험치 구역 | `scenes/main.tscn` → Zones 자식 이동 / 반경·경험치 Inspector |
| 기본형 몸체·나뭇가지·방패 | `scenes/fighter.tscn` → `Visual/Body`의 `Character_Base.png`, `WeaponPivot/Sword`의 `Stick.png`, `Visual/Shield`(진화 후에만 표시) |
| 공격 애니메이션 | 같은 씬 → AnimationPlayer → swing 타임라인 |
| 방패 속도·판정 시간 | `data/balance.tres` → Guard Windup(들기) / Guard Recovery(내리기), 초 단위 |
| 방패 동작·위치 | `scenes/fighter.tscn` → AnimationPlayer → guard_raise / guard_lower 타임라인 |
| 몬스터 이미지 | `scenes/monster.tscn` → Sprite2D |
| 투사체 | `scenes/projectile.tscn`, `scripts/projectile.gd` |
| 체력·스태미나·회복·적 수 | `data/balance.tres` Inspector |
| 스탯·진화·룬 표 | `scripts/catalog.gd` / [유지보수 문서](docs/MAINTENANCE.md) |
| 메뉴·HUD 레이아웃 | `scenes/ui.tscn` |
| 상점·선택창 구성 | `scripts/ui.gd` |
| 효과음 | `assets/*.wav` |

현재 SVG와 WAV는 교체 가능한 기본 에셋입니다. 이미지 변경만으로 판정 범위가 변하지는 않습니다. 기사의 `attack_range_override` 또는 공통 balance의 `attack_range`를 함께 조절하세요. 기술 동작은 `fighter.gd`의 skill 함수, 피해·보스·성장은 `arena.gd`에서 수정합니다.

## Lv.5 클래스별 전투 능력 (임시 스킬 밸런스)

| 클래스 | 일반 전투 | E (임시 쿨타임) |
|---|---|---|
| 검사 | 기존 타이밍 막기 및 기본 검 공격 | **추가 공격!**: 평타 쿨타임을 소비/변경하지 않는 단발 휘두르기, 일반 공격의 125% 피해, 기력 10 소모, E 쿨타임 5초 |
| 창병 | 기본 사거리 138(공격각 42도), 피해를 줄이기만 하는 막기(기력 소모는 유지, 완벽 방어 및 공격자 기력 벌칙 없음) | **돌진!**: 정면 0.2초/속도 650 돌진, 경로에 닿는 대상당 한 번 공격력 50% 피해, E 쿨타임 7초 |
| 망치병 | 공격 누름 시작→놓으면 평타 발동. 0~3초 선형 차징, 피해 100~250%(최대 3초) | **철인**: 최대 체력의 25%를 즉시 회복(상한 최대 체력), E 쿨타임 12초 |
| 방패병 | 평타는 방패 타격. 방패 펼치기가 끝난 뒤 맞은 공격은 HP/기력 손실 없이 전부 흡수하고, 피해량만큼 **방패 게이지**를 소모. 0이면 방어 해제 | **쓸모없음**: 공격력 25% 증가, 6초 지속, E 쿨타임 12초 |

- 방패 게이지 임시값은 최대 100, 방어를 내렸을 때 초당 12 회복입니다. 게이지가 0인 동안에는 방패를 들 수 없습니다. 방패가 깨지는 마지막 공격 역시 온전히 막고, 다음 공격부터 피해를 받습니다.
- 별도로 지속시간·쿨타임이 지정되지 않은 수치는 구현 테스트용 **제안값**입니다. 네 캐릭터의 차별화를 우선 구현했으며 후속 플레이 테스트에서 조정할 예정입니다.
- 전투 구현은 `scripts/characters/{swordsman,spearman,hammerman,shieldbearer}.gd`, 방어 시스템 공용 구현은 `scripts/components/shield_guard.gd`의 `timed/simple/barrier` 세 모드, 피해 판정은 `scripts/arena.gd`입니다.

## Lv.5 네 갈래 진화 (2026-11-18)

시작 캐릭터(나뭇가지 전사)는 Lv.5에서 망치병, 창병, 방패병, 검사 중 하나를 선택할 수 있습니다. 선택지는 `data/characters/roster.tres`의 `data/characters/{hammerman,spearman,shieldbearer,swordsman}.tres`에서 정의합니다. 각 정의의 `evolution_scene`은 `scenes/characters/*.tscn`을 가리킵니다. 씬의 원본 `templates/*.tres`는 편집용 기본 템플릿으로 독립 유지하여 순환 리소스 참조를 피합니다.

`CrownCatalog.evolve()`는 선택 시 `arena.replace_fighter_scene()`으로 캐릭터 씬 자체를 교체합니다. 레벨·XP·체력·기력·스탯·처치 수·기존 스킬은 유지하고, 새 씬의 무기/공격 애니메이션/Guard 컴포넌트를 사용합니다. 망치병과 창병은 방어가 없으며, 방패병과 검사는 방어가 가능합니다. 플레이어와 AI 공통이며, Lv.15/25는 기존 진화 데이터가 남아 있고 현 캐릭터의 외형을 유지한 채 기존 스탯/스킬을 추가합니다. 신규 4종은 아직 전용 액티브 스킬과 수치 밸런스가 확정되지 않았습니다.

## 기본 캐릭터(나뭇가지 전사)

기본형은 GitHub에 업로드된 64×64 투명 PNG(`assets/Character_Base.png`, `assets/Stick.png`)를 사용합니다. 위쪽(-Y)을 기본 정면으로 두며 `facing`은 타격 판정을 향하는 월드 각도, `Visual.rotation = facing + PI/2`는 위를 향해 그려진 몸체 스프라이트의 시각 회전값입니다. 몸체와 스틱은 독립 Sprite2D로 연결했고 `WeaponPivot` 회전 애니메이션을 재사용합니다. 픽셀 선명도를 위해 Visual의 텍스처 필터는 Nearest입니다. 기본형은 막기가 불가능하고 방패가 숨겨지며, 기존 진화 직업부터 막기가 가능해집니다. 이동·대시·기존 성장 시스템은 유지됩니다.

## 조작

- PC: WASD 이동, 좌클릭 공격(선딜/후딜), 우클릭 막기(들기/내리기 딜레이), Shift 달리기, Space 대시(회피), E/R/Q 기술, Esc 일시정지.
- 모바일: 세로·가로 화면 자동 대응. 왼쪽 조이스틱과 오른쪽 공격·막기·대시·기술 버튼. 가까운 적 자동 조준. 회전 시 게임 상태를 유지하고 터치 입력은 초기화합니다.
- 테스트: L 레벨업, B 보스전 (Lv.10 이상). 멀티플레이·실제 결제는 없습니다.

## 프로젝트 GitHub Pages

배포 대상은 사용자 메인 사이트 저장소가 아닌 별도의 프로젝트 저장소입니다. `iron-crown`이라는 공개 저장소라면 주소는 `https://player149.github.io/iron-crown/`입니다.

최초 1회 GitHub Settings → Pages → Source를 **GitHub Actions**로 설정합니다. 이후 main에 커밋을 푸시하면 `.github/workflows/pages.yml`이 Godot 설치 → 검증 → Web export → Pages 배포를 실행합니다. 별도 배포 브랜치나 수동 파일 복사는 필요 없습니다. PR에서는 테스트와 웹 빌드만 실행합니다.

Web 내보내기는 단일 스레드로 설정되어 있으며 에셋 경로는 상대 경로를 사용합니다. 프로젝트 URL 하위에서도 로드됩니다. 실제 배포 완료 여부는 Actions의 build/deploy 결과와 Pages 화면을 확인하세요.

로컬 내보내기 (동일 버전 Export Templates 설치 후):

```sh
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/run.gd
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
python3 -m http.server 8080 --directory build/web
```

브라우저는 `http://localhost:8080`으로 접속합니다. HTML을 파일 앱에서 직접 여는 방식은 지원하지 않습니다.

## 타이밍 전투 프로토타입 (main)

공격: swing AnimationPlayer의 명중 이벤트(기본 0.2초)까지 선딜, 전체 애니메이션(기본 0.42초)이 끝날 때까지 후딜/행동 잠금. 방어: 방패 들기 0.10초 후 피해 감소 적용, 방패 내리기 0.16초 동안 공격/대시 잠금. 기존 대시를 회피로 활용. 공격·대시에서 기력 소모, 방패 들기는 기력 무료, 방어 유지·방어 성공 시 기력 소모. 일반 상태 기력 초당 35 회복, 그로기 지속시간 2초. 평타 1회 그로기 +6, 항상 초당 2 감소(지속 공방에서 약 20회 누적 시 발생). 막은 대상은 그로기 +0, 막힌 공격자는 기본 공격 기력 비용의 1.5배(15) 추가 소모. 방패가 완전히 들린 후 0.10초 안에 막으면 공격자에게 그로기 +60. 방어 판정 진입/해제는 방패 AnimationPlayer 메서드 트랙에서 호출. 수치는 `data/balance.tres` Inspector에서 조정. Guard Windup / Guard Recovery를 바꾸면 방어 판정·행동 잠금과 애니메이션 재생 시간이 함께 바뀝니다. 타임라인 길이는 동작 편집용이며 실행 시 설정한 시간에 맞춰 재생됩니다.

## 기력 소진 및 처치 보상

- 최대 기력은 기본 100으로, 레벨업 자체로 증가하지 않습니다. 기력이 완전히 소진되면 1초 동안 탈진해 이동·공격·막기·대시·스킬이 제한됩니다. 탈진 중에는 기력이 회복되지 않으며 종료 후 일반 회복이 재개됩니다. 막힌 공격의 기력 페널티, 막기 유지, 방어 성공으로도 탈진이 발생할 수 있습니다.
- 기사 처치 시 피해 기여자 수를 계산합니다. 대상에게 최근 전투 지속시간(기본 5초) 내 피해를 준 고유 공격자만 인정하며 중복 공격은 한 명으로 셉니다. 마지막 타격자는 1인 기여 처치면 완전 회복, 여러 명이 기여한 경우 최대 체력의 1/N만큼 현재 체력을 회복합니다. 기력은 기여자 수와 관계없이 100% 회복됩니다.
- 기여 기록은 피해자의 사망·부활·보스전 진입 시 정리합니다. 기여자 모두에게 회복을 나누는 것이 아니라 마지막 타격자의 회복량을 인원수로 나눕니다.

## 저장과 기획

골드·룬·시작권·이름은 `user://iron_crown_v2.json`에 저장됩니다. 웹에서는 브라우저 저장소를 사용하므로 기기 사이 자동 동기화가 되지 않습니다. 같은 origin의 기존 HTML 게임 `ironCrownMeta`가 있으면 최초 실행 때 가져옵니다. 브라우저 데이터 삭제 시 세이브도 삭제될 수 있습니다.

기획 기준: [Iron Crown Notion](https://app.notion.com/p/3deea58678318054b21ee776c2e7c7e8). 이후 변경 시 Notion과 이 프로젝트 문서를 함께 최신화합니다.

폰트: Noto Sans KR (SIL OFL, `assets/OFL.txt`). 원본 Google Fonts 글꼴의 한글·라틴 문자, 굵기 500을 포함한 경량 파일입니다.

## 캐릭터·스킬 제작

기본 캐릭터 씬에서 시작하는 제작 흐름, 진화 계보 리소스와 애니메이션 이벤트 설정은 [캐릭터 제작 안내](docs/CHARACTER_AUTHORING.md)를 참고하세요. 현재 본편의 9개 진화와 기술은 `data/characters/`, `data/abilities/`로 분리되어 있습니다.
