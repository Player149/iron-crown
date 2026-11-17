# 캐릭터와 스킬 제작

## 씬과 스크립트의 책임

- scenes/fighter.tscn: 몸체, 무기 관절, 충돌, UI를 제공하는 구조용 부모 씬. AnimationPlayer와 방패는 포함하지 않는다.
- scripts/fighter.gd: 공통 이동, 입력, 공격, 스태미나, 그로기, 스킬 실행. 선택적인 Guard 컴포넌트에 입력과 초기화를 전달한다.
- scenes/characters/base_knight.tscn: 전장에서 생성하는 기존 나뭇가지 시작 캐릭터. 로컬 AnimationPlayer를 직접 소유한다.
- scripts/components/shield_guard.gd: 방어 상태 전환, 방패 연출, 방어 스태미나, 피격 감쇄, 공격자 스태미나 페널티, 완벽 방어와 반격 그로기.
- scripts/arena.gd: 일반 피해와 처치/회복 처리. 대상에 Guard가 있으면 receive_hit(source)로 방패 반응을 위임한다.

## 병종 틀

| 병종 | scenes/characters 아래 씬 | scripts/characters 아래 스크립트 |
| --- | --- | --- |
| 검사 | swordsman.tscn | swordsman.gd |
| 창병 | spearman.tscn | spearman.gd |
| 방패병 | shieldbearer.tscn | shieldbearer.gd |
| 망치병 | hammerman.tscn | hammerman.gd |

기본 기사와 네 병종은 모두 fighter.tscn을 상속한다. 각각 자기 씬에 AnimationPlayer와 내장 AnimationLibrary/Animation을 직접 저장한다. 검·창·망치·방패는 프로젝트의 sword_A.png, Spear.png, hammer.png, Shield_Big1.png를 사용한다. WeaponPivot1/WeaponPivot2 관절은 공통이며 장비 Sprite2D는 각 캐릭터 씬에 직접 둔다. 방패병에는 Sword 노드가 없고 swing은 방패 밀치기를 재생한다.

각 병종의 definition은 data/characters/templates에 있으며 기존 진화 리소스와 분리했다. 제작용 씬은 자동 스폰/진화 목록에 아직 연결하지 않았다. 공격 모션과 수치는 제작 출발점으로 공통값을 사용한다.

## 애니메이션 추가와 편집

1. 수정할 캐릭터의 tscn을 직접 연다. 구조용 fighter.tscn이나 전장에 배치된 인스턴스를 열지 않는다.
2. 그 씬의 AnimationPlayer를 선택한다. 애니메이션 패널에서 새로 만들기, 키프레임 수정, 이름 변경, 삭제를 한다.
3. 기본 기사/각 병종에 라이브러리와 애니메이션이 로컬로 저장되어 있으므로 상속 원본의 읽기 전용 키프레임을 편집할 필요가 없다. 병종별 수정은 다른 병종에 영향을 주지 않는다. 실행 중 인스턴스의 라이브러리도 깊게 복제한다.
4. 편집 후 캐릭터 씬을 저장한다. 같은 병종의 새 인스턴스에는 해당 씬의 수정이 적용된다.

기본 공격 이름은 swing이며 메서드 트랙은 루트(.)의 resolve_attack_hit()을 호출한다. 새 연출을 만들 때 이 타격 이벤트를 원하는 프레임에 둔다. RESET은 무기 관절의 기본 자세다. 두 애니메이션은 현재 전투/편집 계약이므로 무작정 이름을 바꾸거나 삭제하지 않는다. 별도 idle/walk 등 애니메이션은 자유롭게 추가할 수 있지만 자동 재생 조건은 전용 스크립트에서 연결해야 한다.

시각 트랙은 Visual 아래에 둔다. 예: Visual/WeaponPivot1:rotation, Visual/WeaponPivot1/WeaponPivot2:rotation. 루트 position에 기본값 키를 넣으면 전장 좌표가 바뀐다. 연출 이동은 Visual:position으로 만든다.

## 방패 컴포넌트

검사는 검과 작은 방패(Visual/Shield)를, 방패병은 큰 방패(Visual/WeaponPivot1/WeaponPivot2/Shield)만 소유한다. 두 병종에 Guard(Node2D, shield_guard.gd)가 있다. 기본 기사·창병·망치병에는 가드 애니메이션이나 Guard가 없고, 진화 여부만으로 가드가 생기지 않는다. 다른 병종에 방패 기능이 필요하면 이 컴포넌트를 명시적으로 추가한다.

방패병의 로컬 guard_raise/guard_lower는 Shield 위치 트랙과 Guard 대상의 on_guard_raised()/on_guard_lowered() 메서드 키를 가진다. 길이는 balance의 guard_windup/guard_recovery에 맞춰 재생 속도를 조절한다. 방어 효과·완벽 방어 수치는 balance와 fighter의 block_reduction을 사용한다. 방패 공격 기능을 추가할 때도 방패 전용 동작은 이 컴포넌트에 확장한다. 현재 새 방패 공격 스킬을 추가한 것은 아니다.

Guard 인스펙터의 raise_animation/lower_animation으로 다른 이름의 연출을 연결할 수 있다. 가드 메서드 키를 삭제해도 애니메이션 종료 시 상태 전환을 완료한다. 가드 애니메이션 자체를 삭제하면 타이머로 준비/회복 시간을 처리하므로 누락 노드 오류나 영구 행동 잠금이 생기지 않는다. 가드 전환 애니메이션은 반복 재생하지 않는다. 방패 위치를 매 프레임 코드로 덮어쓰지 않으므로 직접 키프레임을 편집할 수 있다.

## 정의, 진화와 스킬

캐릭터별 기본 공격은 definition.attack_animation으로 외부 Animation을 연결할 수도 있다. 지정하면 실행 시 로컬 swing을 대체하므로 씬에서 편집한 swing을 쓰려면 이 필드를 비워 둔다. definition의 attack_cooldown/attack_target_limit은 공격 쿨타임과 대상 수다(0은 무제한). multipliers/additions는 기본 캐릭터 생성 시 또는 진화 선택 시 한 번 적용한다. 사거리는 씬 루트의 attack_range_override로 조절한다.

data/characters/roster.tres는 기존 진화 목록이다. unlock_level은 선택 레벨, parent_ids는 이전 직업 ID 제한이며 빈 배열이면 모두 허용한다. data/abilities의 기술은 character의 skill_slot/ability로 연결한다. 기술 Animation 메서드 트랙은 루트의 resolve_skill_hit("e") 등을 호출한다. 각 Skill_E/R/Q 플레이어는 슬롯별 애니메이션을 독립적으로 재생한다. 입력 시 쿨타임을 처리하고 실제 효과는 이벤트에서 실행한다.

## 적용과 검증

전장 시작 캐릭터를 바꾸려면 arena.gd의 FighterScene 경로를 해당 씬으로 변경한다. 캐릭터는 생성 시 arena를 지정해야 하므로 캐릭터 씬 단독 F6 실행 대신 main.tscn을 실행한다.

- godot --headless --path . --script res://tests/character_templates.gd
- godot --headless --path . --script res://tests/run.gd
- godot --headless --path . --script res://tests/playback.gd
- godot --headless --path . --script res://tests/layout.gd
