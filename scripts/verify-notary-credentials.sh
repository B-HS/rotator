#!/usr/bin/env bash
set -euo pipefail

echo "Apple 공증 자격 증명을 제출 없이 검증합니다(notarytool history)."
echo

if [ -n "${APPLE_ID:-}" ]; then
    NOTARY_ID="$APPLE_ID"
else
    read -r -p "APPLE_ID (Apple 계정 이메일): " NOTARY_ID
fi

if [ -n "${APPLE_TEAM_ID:-}" ]; then
    NOTARY_TEAM="$APPLE_TEAM_ID"
else
    read -r -p "APPLE_TEAM_ID (10자리): " NOTARY_TEAM
fi

if [ -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]; then
    NOTARY_PASSWORD="$APPLE_APP_SPECIFIC_PASSWORD"
else
    read -rs -p "APPLE_APP_SPECIFIC_PASSWORD: " NOTARY_PASSWORD
    echo
fi

NOTARY_ID="$(printf '%s' "$NOTARY_ID" | tr -d ' \t\r\n')"
NOTARY_TEAM="$(printf '%s' "$NOTARY_TEAM" | tr -d ' \t\r\n')"
NOTARY_PASSWORD="$(printf '%s' "$NOTARY_PASSWORD" | tr -d ' \t\r\n')"

if ! printf '%s' "$NOTARY_TEAM" | grep -Eq '^[A-Z0-9]{10}$'; then
    echo "[경고] APPLE_TEAM_ID는 일반적으로 영문 대문자와 숫자 10자리입니다."
fi

echo "[검증] Apple 공증 서버 인증 시도 중..."
if xcrun notarytool history \
    --apple-id "$NOTARY_ID" \
    --team-id "$NOTARY_TEAM" \
    --password "$NOTARY_PASSWORD" >/dev/null; then
    echo "[통과] 공증 자격 증명이 유효합니다."
    echo "GitHub Actions secrets에 APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, APPLE_TEAM_ID로 등록하세요."
else
    echo "[실패] Apple ID, 앱 전용 암호, Team ID를 다시 확인하세요." >&2
    exit 1
fi
