#!/usr/bin/env bash
set -euo pipefail

INPUT="${1:-}"
if [ -z "$INPUT" ] || [ ! -f "$INPUT" ]; then
    echo "사용법: ./scripts/verify-signing-cert.sh <certificate.p12 | base64.txt>"
    echo "비밀번호는 CERT_PASSWORD 환경변수 또는 안전한 프롬프트로 입력합니다."
    exit 2
fi

WORK="$(mktemp -d)"
KEYCHAIN="$WORK/verify.keychain-db"
P12="$WORK/certificate.p12"

cleanup() {
    security delete-keychain "$KEYCHAIN" 2>/dev/null || true
    rm -rf "$WORK"
}
trap cleanup EXIT

MAGIC="$(head -c 2 "$INPUT" | od -An -tx1 | tr -d ' \n')"
if [ "$MAGIC" = "3082" ]; then
    MODE="p12"
    cp "$INPUT" "$P12"
    echo "[1/3 통과] PKCS#12 원본 파일을 확인했습니다."
else
    MODE="base64"
    CLEAN="$(tr -d ' \t\r\n' < "$INPUT")"
    if ! printf '%s' "$CLEAN" | grep -Eq '^[A-Za-z0-9+/]*={0,2}$'; then
        echo "[1/3 실패] 올바르지 않은 base64 문자가 포함되어 있습니다." >&2
        exit 1
    fi
    if [ $(( ${#CLEAN} % 4 )) -ne 0 ]; then
        echo "[1/3 실패] base64 값이 잘렸습니다(길이가 4의 배수가 아님)." >&2
        exit 1
    fi
    printf '%s' "$CLEAN" | base64 -d > "$P12"
    echo "[1/3 통과] base64 디코딩에 성공했습니다."
fi

if [ -n "${CERT_PASSWORD:-}" ]; then
    PASSWORD="$CERT_PASSWORD"
else
    read -rs -p "MACOS_CERTIFICATE_PASSWORD: " PASSWORD
    echo
fi

security create-keychain -p verify "$KEYCHAIN"
security unlock-keychain -p verify "$KEYCHAIN"
if ! security import "$P12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign >/dev/null 2>&1; then
    echo "[2/3 실패] 인증서 임포트 실패: 비밀번호 또는 p12 파일을 확인하세요." >&2
    exit 1
fi
echo "[2/3 통과] 임시 키체인 임포트에 성공했습니다."

IDENTITY="$(security find-identity -p codesigning "$KEYCHAIN" | sed -n 's/.*"\(.*\)".*/\1/p' | head -1)"
if [ -z "$IDENTITY" ]; then
    echo "[3/3 실패] Developer ID Application 서명 아이덴티티가 없습니다." >&2
    exit 1
fi
echo "[3/3 통과] $IDENTITY"

if [ "$MODE" = "p12" ]; then
    openssl base64 -A -in "$INPUT" | tr -d '\n' | pbcopy
else
    tr -d ' \t\r\n' < "$INPUT" | pbcopy
fi

echo "GitHub secret MACOS_CERTIFICATE_P12에 넣을 한 줄 base64 값을 클립보드에 복사했습니다."
echo "MACOS_CERTIFICATE_PASSWORD에는 방금 검증한 p12 비밀번호를 등록하세요."
