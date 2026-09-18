#!/usr/bin/env bash
set -euo pipefail

REPO="${ROTATOR_GITHUB_REPO:-B-HS/rotator}"
PROJECT_DIR="$(cd -- "$(dirname -- "$0")/.." && pwd)"
ENV_DIR="${ROTATOR_ENV_DIR:-/Users/hyunseokbyun/environment}"
DEFAULT_P12="$ENV_DIR/Certificates.p12"
DEFAULT_APP_PASSWORD_FILE="$ENV_DIR/comon-app-sepcific-pwd.txt"

prompt_file() {
    local label="$1"
    local default_path="$2"
    local value

    while true; do
        read -r -p "$label [$default_path]: " value
        value="${value:-$default_path}"
        if [ -f "$value" ]; then
            printf '%s' "$value"
            return 0
        fi
        echo "[실패] 파일을 찾을 수 없습니다: $value" >&2
    done
}

prompt_apple_id() {
    local value
    while true; do
        read -r -p "APPLE_ID (Apple 계정 이메일): " value
        value="$(printf '%s' "$value" | tr -d ' \t\r\n')"
        case "$value" in
            *@*.*)
                echo "[통과] Apple ID 이메일 형식"
                APPLE_ID_VALUE="$value"
                return 0
                ;;
            *)
                echo "[실패] 이메일 형식으로 입력해 주세요." >&2
                ;;
        esac
    done
}

prompt_team_id() {
    local value
    while true; do
        read -r -p "APPLE_TEAM_ID (영문 대문자·숫자 10자리): " value
        value="$(printf '%s' "$value" | tr -d ' \t\r\n' | tr '[:lower:]' '[:upper:]')"
        if printf '%s' "$value" | grep -Eq '^[A-Z0-9]{10}$'; then
            echo "[통과] Team ID 형식"
            APPLE_TEAM_ID_VALUE="$value"
            return 0
        fi
        echo "[실패] Team ID는 영문 대문자와 숫자 10자리여야 합니다." >&2
    done
}

prompt_app_password() {
    local file value
    while true; do
        file="$(prompt_file "Apple 앱 전용 암호 파일" "$DEFAULT_APP_PASSWORD_FILE")"
        value="$(tr -d '[:space:]' < "$file")"
        if printf '%s' "$value" | grep -Eq '^[a-z]{4}-[a-z]{4}-[a-z]{4}-[a-z]{4}$'; then
            chmod 600 "$file"
            echo "[통과] Apple 앱 전용 암호 형식"
            APPLE_APP_PASSWORD_VALUE="$value"
            return 0
        fi
        echo "[실패] 파일 값이 xxxx-xxxx-xxxx-xxxx 형식이 아닙니다." >&2
    done
}

cd "$PROJECT_DIR"

echo "Rotator GitHub Actions Secrets 설정"
echo "비밀값은 터미널에 표시하지 않습니다."
echo

echo "[1/6] GitHub 로그인 확인"
if gh auth status >/dev/null 2>&1; then
    echo "[통과] GitHub CLI 로그인"
else
    echo "GitHub CLI 로그인이 필요합니다. 브라우저 인증을 시작합니다."
    gh auth login -h github.com -p https -w
    gh auth status >/dev/null
    echo "[통과] GitHub CLI 로그인"
fi

echo
echo "[2/6] Developer ID 인증서 확인"
P12_FILE="$(prompt_file "Developer ID .p12 파일" "$DEFAULT_P12")"
chmod 600 "$P12_FILE"
while true; do
    read -rs -p "MACOS_CERTIFICATE_PASSWORD: " CERT_PASSWORD_VALUE
    echo
    if CERT_PASSWORD="$CERT_PASSWORD_VALUE" ./scripts/verify-signing-cert.sh "$P12_FILE"; then
        echo "[통과] 인증서와 비밀번호 검증"
        break
    fi
    echo "[재시도] p12 비밀번호를 다시 입력해 주세요." >&2
done

echo
echo "[3/6] Apple ID 확인"
prompt_apple_id

echo
echo "[4/6] Apple Team ID 확인"
prompt_team_id

echo
echo "[5/6] Apple 앱 전용 암호 확인"
prompt_app_password

echo
echo "[6/6] Apple 공증 서버 실제 인증"
while ! APPLE_ID="$APPLE_ID_VALUE" \
    APPLE_TEAM_ID="$APPLE_TEAM_ID_VALUE" \
    APPLE_APP_SPECIFIC_PASSWORD="$APPLE_APP_PASSWORD_VALUE" \
    ./scripts/verify-notary-credentials.sh; do
    echo
    echo "공증 인증에 실패했습니다. 수정할 항목을 선택하세요."
    echo "  1) Apple ID"
    echo "  2) Team ID"
    echo "  3) 앱 전용 암호 파일"
    echo "  4) 종료"
    read -r -p "선택: " choice
    case "$choice" in
        1) prompt_apple_id ;;
        2) prompt_team_id ;;
        3) prompt_app_password ;;
        4) exit 1 ;;
        *) echo "1~4 중에서 선택해 주세요." >&2 ;;
    esac
done

echo
read -r -p "검증된 5개 값을 $REPO GitHub Actions Secrets에 등록할까요? [y/N]: " confirm
case "$confirm" in
    y|Y|yes|YES)
        openssl base64 -A -in "$P12_FILE" |
            gh secret set MACOS_CERTIFICATE_P12 --repo "$REPO"
        printf '%s' "$CERT_PASSWORD_VALUE" |
            gh secret set MACOS_CERTIFICATE_PASSWORD --repo "$REPO"
        printf '%s' "$APPLE_ID_VALUE" |
            gh secret set APPLE_ID --repo "$REPO"
        printf '%s' "$APPLE_TEAM_ID_VALUE" |
            gh secret set APPLE_TEAM_ID --repo "$REPO"
        printf '%s' "$APPLE_APP_PASSWORD_VALUE" |
            gh secret set APPLE_APP_SPECIFIC_PASSWORD --repo "$REPO"

        unset CERT_PASSWORD_VALUE APPLE_ID_VALUE APPLE_TEAM_ID_VALUE APPLE_APP_PASSWORD_VALUE
        echo
        echo "[완료] 등록된 GitHub Actions Secrets"
        gh secret list --repo "$REPO"
        ;;
    *)
        echo "등록하지 않았습니다. 검증은 모두 통과했습니다."
        ;;
esac
