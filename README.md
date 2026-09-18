# Rotator

macOS 메뉴 막대에서 내장 디스플레이와 외장 모니터를 0°/90°/180°/270°로 회전하는 작은 Swift 앱입니다.

## 기능

- Dock에는 나타나지 않고 메뉴 막대에만 표시
- 연결된 모든 디스플레이를 각각 하위 메뉴로 표시
- 현재 회전 각도에 체크 표시
- 변경 후 10초 동안 유지 여부 확인
- 확인하지 않거나 `되돌리기`를 누르면 이전 각도로 자동 복원
- 메뉴에서 macOS 디스플레이 설정 바로 열기
- 메뉴 막대와 앱 아이콘에 동일한 `rectangle.landscape.rotate` 심볼 사용

## 로컬 빌드

Xcode 15 이상과 macOS 13 이상이 필요합니다.

```bash
./scripts/build-app.sh
open build/Rotator.app
```

빌드 스크립트는 Apple Silicon과 Intel을 모두 지원하는 Universal Binary를 만들고 다음 결과물을 생성합니다.

- `build/Rotator.app`
- `dist/Rotator-1.0.0-macOS-universal.zip`

Developer ID 인증서가 없으면 로컬 테스트가 가능한 임시 서명을 사용합니다.

## Developer ID 서명 및 공증

배포용 Developer ID Application 인증서를 지정해 빌드합니다.

```bash
SIGNING_IDENTITY="Developer ID Application: 이름 (TEAMID)" ./scripts/build-app.sh
```

Apple 계정 정보를 `notarytool` 키체인 프로필로 한 번 저장합니다.

```bash
xcrun notarytool store-credentials "rotator-notary" \
  --apple-id "APPLE_ID" \
  --team-id "TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

그 후 공증하고 티켓을 앱에 첨부합니다.

```bash
NOTARY_PROFILE="rotator-notary" ./scripts/notarize.sh
```

로컬 인증서와 공증 자격은 실제 배포 전에 다음 스크립트로 검증할 수 있습니다. 비밀값은 저장소 파일에 기록되지 않습니다.

```bash
./scripts/verify-signing-cert.sh /path/to/developer-id.p12
./scripts/verify-notary-credentials.sh
```

## GitHub Draft Release

`prod` 브랜치에 푸시하면 `.github/workflows/release.yml`이 테스트, Universal 빌드, Developer ID 서명, Apple 공증과 스테이플을 수행한 뒤 Draft Release를 만듭니다. `dev` 푸시에는 릴리스가 생성되지 않습니다.

저장소의 **Settings → Secrets and variables → Actions**에 다음 Repository secrets를 등록해야 합니다.

- `MACOS_CERTIFICATE_P12`: Developer ID Application `.p12` 파일의 한 줄 base64
- `MACOS_CERTIFICATE_PASSWORD`: `.p12` 비밀번호
- `APPLE_ID`: Apple Developer 계정 이메일
- `APPLE_APP_SPECIFIC_PASSWORD`: Apple 앱 전용 암호
- `APPLE_TEAM_ID`: 10자리 Team ID
- `APPLE_SIGNING_IDENTITY`: 선택 사항. 비워 두면 인증서에서 자동 탐색

## 기술적 참고

macOS의 공개 CoreGraphics API는 현재 각도를 읽을 수 있지만 화면 회전을 설정하는 공개 API는 제공하지 않습니다. Rotator는 macOS의 MonitorPanel 기능을 런타임에 사용하며, 사용할 수 없는 구형 시스템에서는 IOKit 방식으로 시도합니다. 따라서 Mac App Store 배포용 앱이 아니며 macOS 업데이트에 따라 동작 방식이 바뀔 수 있습니다.

일부 디스플레이 어댑터, DisplayLink 장치 또는 미러링 구성은 회전을 거부할 수 있습니다. 내장 디스플레이를 회전하는 동안 화면이 잠시 꺼졌다 켜지는 현상은 정상입니다.
