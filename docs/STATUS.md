# 2026-09-21 배포 완료

- 프로젝트 사이트: https://player149.github.io/iron-crown/
- 개발 원본: https://github.com/Player149/iron-crown
- 성공한 자동 빌드/배포: https://github.com/Player149/iron-crown/actions/runs/35612093824
- 배포 코드 커밋: 9b7e069efe66ec164fce3356f9d23b388d556506
- Godot 4.5.1 에디터 import, 핵심 자동 검증 34개, Web release export 성공. GitHub에서도 같은 테스트 및 배포 성공.
- HTML / JS / PCK / WASM / service worker / manifest 모두 HTTP 200 확인.
- 확인용 클라우드 브라우저는 WebGL2 미지원으로 실제 플레이 검증 불가. WebGL2 지원 브라우저와 실제 휴대폰에서 플레이·터치·저장 이전은 후속 확인 필요.
- 기존 사용자 메인 사이트 Player149.github.io는 변경하지 않음.
- 이후 main 푸시 → Actions 자동 검증·Web export·Pages 배포.
