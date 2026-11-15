# 캐릭터와 스킬 제작

## 구성

- `scenes/characters/base_knight.tscn`: 실제 전장이 생성하는 기본 캐릭터. `fighter.tscn`을 상속한다.
- `scripts/fighter.gd`: 이동·입력·자원·애니메이션 실행과 근접 판정. 직업별 분기를 넣지 않는다.
- `data/characters/*.tres`: 이름, 해금 레벨, 이전 진화 ID, 능력치 변경, 장착 스킬.
- `data/characters/roster.tres`: 게임에서 사용하는 캐릭터 목록. 여기에 추가하면 진화 UI와 AI 선택에 함께 반영된다.
- `data/abilities/*.tres`: 기술 효과, 피해 배율, 범위/투사체, 쿨타임, 비용, Animation 리소스.
- 기본 공격은 기존 `AnimationPlayer/swing`, 기술은 캐릭터마다 생성되는 `Skill_E`, `Skill_R`, `Skill_Q`가 재생한다. 기술 슬롯끼리 애니메이션이 덮어써지지 않는다.

## 기본형에서 새 캐릭터 만들기

1. Godot에서 `base_knight.tscn`을 상속한 새 씬을 만든다. 외형은 `Visual` 아래에서 변경한다.
2. `knight.tres`를 복제하고 고유 `id`, `title`, `multipliers`, `additions`를 지정한다. 새 씬 루트의 `definition`에 연결한다.
3. 진화 캐릭터라면 기존 진화 리소스를 복제한다. `unlock_level`, `skill_slot`, `ability`를 지정하고 roster의 characters 배열에 추가한다.
4. `parent_ids`가 비어 있으면 해당 단계의 모든 이전 직업에서 선택 가능하다. 특정 계보만 허용하려면 바로 이전 진화의 ID를 넣는다. 시작 단계는 `knight` 등 기본 definition의 ID를 넣는다.
5. 기존 캐릭터는 Lv.5/15/25에 모두 선택 가능하도록 유지했다. 자식이 없는 분기는 해당 레벨의 진화 선택을 건너뛴다.

능력치 키는 Fighter의 프로퍼티명이다. 예: multipliers의 `damage: 1.2`는 공격력 20% 증가, additions의 `armor: 7`은 방어력 7 증가다. 기본형에서는 생성 시, 진화에서는 선택 시 한 번 적용한다.

## 공격 타이밍 편집

기본 공격 `swing`의 **메서드 호출 트랙**에서 루트 Fighter를 대상으로 `resolve_attack_hit()` 키를 놓는다. 현재 0.2초 키는 애니메이션 데이터이며 코드 타이머가 아니다. 공격 속도에 따라 애니메이션과 이벤트가 함께 빨라진다.

캐릭터별 기본 공격이 필요하면 Animation을 외부 `.tres`로 저장하고 definition의 `attack_animation`에 연결한다. 실행 중 각 캐릭터는 별도 AnimationLibrary를 사용한다. 쿨타임은 기본 definition의 `attack_cooldown`, 공격 대상 수는 진화 definition의 `attack_target_limit`(0은 무제한)에서 설정한다.

**이동 연출은 `Visual:position`을 애니메이션으로 변경한다.** 루트의 `position`은 전장 좌표이므로 0으로 키를 찍으면 캐릭터가 원점으로 이동한다. 실제 돌진 이동은 스킬의 dash_duration/dash_speed를 사용한다.

## 새 스킬과 애니메이션

1. 기존 ability `.tres`를 복제하고 effect, power, radius 또는 projectile 설정을 수정한다.
2. AnimationPlayer에서 새 Animation을 만들고 루트 Fighter에 대한 메서드 호출 트랙을 추가한다. E 기술은 `resolve_skill_hit("e")`, R/Q는 각각 해당 문자열을 인자로 넣는다.
3. 필요한 타격 프레임에 호출 키를 배치한다. Animation을 외부 리소스로 저장하고 ability의 animation에 연결한다. 기존 ability 안의 Animation을 직접 편집해도 된다.
4. 시각 트랙은 루트 기준 경로를 사용한다. 예: `Visual/WeaponPivot:rotation`. 여러 슬롯이 같은 시각 프로퍼티를 동시에 움직이면 충돌할 수 있으므로 전용 이펙트 자식 노드를 권장한다.
5. character 리소스의 ability와 skill_slot을 지정한다. 입력 시 비용과 쿨타임만 처리하고, 실제 효과는 Animation 이벤트에서 실행한다.

현재 기술은 1회 사용당 첫 유효 이벤트에서 효과를 한 번 실행한다. 여러 투사체는 projectile_count로 구성한다. 다단 타격의 서로 다른 이벤트, 소환, 지속 장판 같은 새로운 동작은 `CrownAbility`를 상속해 execute(f)를 재정의하는 방식으로 확장한다. 현재 데이터의 이벤트가 없는 Animation은 피해를 발생시키지 않는다.

일시정지/선택창 중 도착한 이벤트와 사망·탈진 상태의 이벤트는 효과를 내지 않는다. 스킬 장착을 교체하면 이전 사용 대기 상태는 취소된다. 리소스에는 쿨타임 잔량이나 시전자 상태를 저장하지 않는다.

## 확인

`godot --headless --path . --script res://tests/run.gd`로 전투·성장·보스 복원 및 애니메이션 이벤트 전/후 효과, 중복 이벤트 방지, 캐릭터별 스킬 분리를 검사한다. 새 직업은 에디터에서 연출과 실제 사거리도 확인한다.
