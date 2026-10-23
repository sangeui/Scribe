# Claude Code 프로젝트 가이드 (CLAUDE.md)

이 저장소의 빌드·테스트·버전 관리·릴리스 규칙과 문서 작성 원칙은 [`AGENTS.md`](AGENTS.md) 및 [`RELEASE.md`](RELEASE.md)에 통합 정의되어 있습니다. 작업 착수 전 반드시 [`AGENTS.md`](AGENTS.md)를 먼저 읽고 동일하게 준수하세요.

## 핵심 요약
- **코드 변경 후 필수 검증**: `./scripts/test-gate.sh` (`PASS` 확인)
- **문서·버전 일관성 검사**: `./scripts/release.sh --check-only`
- **단일 버전 원본**: 루트 [`VERSION`](VERSION) 파일 (수동 개별 수정 금지)
- **베타 버전 정책 (`0.x.y`)**: 현재 베타 단계이므로 메이저 버전(`1.0.0` 이상)은 올리지 않으며 `patch`(`0.1.x`) 또는 `minor`(`0.x.0`)만 사용
- **AI 자율 버전 결정**: 배포 요청 시 `./scripts/release.sh --diff`로 직전 버전(`v$(cat VERSION)`) 대비 변경 내역을 직접 비교해, 신규 기능·콘텐츠가 포함되었으면 `minor`, 버그·UI·문서 수정만 있으면 `patch`를 AI가 스스로 결정하여 실행
- **릴리스 배포**: `./scripts/release.sh <patch|minor|0.X.Y>` (기존 태그 덮어쓰기 절대 금지)
- **문서 작성 규칙**: `README.md`, `README.en.md`, About 등에 작품 수·작가 수 등 변경될 수 있는 특정 숫자를 표기하지 않음
