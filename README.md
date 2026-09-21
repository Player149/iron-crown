# IRON CROWN · Godot edition

Godot 4.5.1 / GDScript / Compatibility 렌더러로 이식한 싱글플레이 아레나 게임입니다. 원본 HTML을 감싼 형태가 아니라 Godot 씬·노드·리소스·AnimationPlayer로 구성했습니다.

## 열기 / 편집

Godot 4.5.1에서 이 저장소의 `project.godot`을 가져온 뒤 실행(F6: 현재 씬, F5: 게임)합니다. Android Godot 에디터에서도 같은 폴더를 열 수 있습니다. PC와 모바일은 같은 파일 구조를 사용하며 Git으로 커밋·푸시·풀합니다. 기기 사이의 동기화는 자동 파일 복사가 아니라 Git 변경사항 동기화입니다.

| 편집할 내용 | 파일 / 에디터 위치 |
|---|---|
| 맵과 경험치 구역 | `scenes/main.tscn` → Zones 자식 이동 / 반경·경험치 Inspector |
| 기사 이미지·검·방패 | `scenes/fighter.tscn` → Visual의 Sprite2D Texture |
| 공격 애니메이션 | 같은 씬 → AnimationPlayer → swing 타임라인 |
| 몬스터 이미지 | `scenes/monster.tscn` → Sprite2D |
| 투사체 | `scenes/projectile.tscn`, `scripts/projectile.gd` |
| 체력·스태미나·회복·적 수 | `data/balance.tres` Inspector |
| 스탯·진화·룬 표 | `scripts/catalog.gd` / [유지보수 문서](docs/MAINTENANCE.md) |
| 메뉴·HUD 레이아웃 | `scenes/ui.tscn` |
| 상점·선택창 구성 | `scripts/ui.gd` |
| 효과음 | `assets/*.wav` |

현재 SVG와 WAV는 교체 가능한 기본 에셋입니다. 이미지 변경만으로 판정 범위가 변하지는 않습니다. 기사의 `attack_range_override` 또는 공통 balance의 `attack_range`를 함께 조절하세요. 기술 동작은 `fighter.gd`의 skill 함수, 피해·보스·성장은 `arena.gd`에서 수정합니다.

## 조작

- PC: WASD 이동, 좌클릭 공격, 우클릭 막기, Shift 달리기, Space 대시, E/R/Q 기술, Esc 일시정지.
- 모바일: 가로 화면 권장. 왼쪽 조이스틱과 오른쪽 공격·막기·대시·기술 버튼. 가까운 적 자동 조준.
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

## 저장과 기획

골드·룬·시작권·이름은 `user://iron_crown_v2.json`에 저장됩니다. 웹에서는 브라우저 저장소를 사용하므로 기기 사이 자동 동기화가 되지 않습니다. 같은 origin의 기존 HTML 게임 `ironCrownMeta`가 있으면 최초 실행 때 가져옵니다. 브라우저 데이터 삭제 시 세이브도 삭제될 수 있습니다.

기획 기준: [Iron Crown Notion](https://app.notion.com/p/3deea58678318054b21ee776c2e7c7e8). 이후 변경 시 Notion과 이 프로젝트 문서를 함께 최신화합니다.

폰트: Noto Sans KR (SIL OFL, `assets/OFL.txt`). 원본 Google Fonts 글꼴의 한글·라틴 문자, 굵기 500을 포함한 경량 파일입니다.
