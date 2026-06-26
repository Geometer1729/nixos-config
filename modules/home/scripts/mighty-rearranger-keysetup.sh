#!/usr/bin/env bash
set -euo pipefail

linear_source_path="${1:-/run/secrets/linear_api_key}"
linear_target_key="geosurge.ai/linear.app/api-key"
slack_source_path="${SLACK_TOKEN_SOURCE:-/run/secrets/slack_token}"
slack_target_key="geosurge.ai/api.slack.com/vibeos-mirror/bot_api"
google_oauth_source_path="${GOOGLE_OAUTH_SOURCE:-}"
google_client_id_source_path="${GOOGLE_CLIENT_ID_SOURCE:-/run/secrets/gcloud_client_id}"
google_client_secret_source_path="${GOOGLE_CLIENT_SECRET_SOURCE:-/run/secrets/gcloud_secret}"
google_oauth_target_key="accounts.google.com/geosurge.ai/dnd-knowledge-bases/oauth/production"
identity_path="${RAGEVEIL_IDENTITY:-$HOME/.config/sops/age/keys.txt}"
store_path="${RAGEVEIL_STORE:-$HOME/.rageveil}"
mirror_data_dir="${MIRROR_DATA_DIR:-$HOME/.local/state/mighty-rearranger}"
google_email_auth="${GOOGLE_EMAIL_AUTH:-1}"
force_google_email_auth="${FORCE_GOOGLE_EMAIL_AUTH:-0}"

validate_google_oauth_json() {
  jq -e '(
    (.installed | type == "object" and .client_id and .client_secret) or
    (.web | type == "object" and .client_id and .client_secret)
  )' >/dev/null
}

insert_key() {
  local label="$1"
  local source_path="$2"
  local target_key="$3"
  local expected_prefix="${4:-}"

  if [[ ! -r "$source_path" ]]; then
    echo "cannot read $label from $source_path" >&2
    exit 1
  fi

  local payload
  payload=$(<"$source_path")
  if [[ -z "$payload" ]]; then
    echo "$label at $source_path is empty" >&2
    exit 1
  fi

  if [[ -n "$expected_prefix" && "$payload" != "$expected_prefix"* ]]; then
    echo "$label at $source_path has the wrong token type" >&2
    echo "expected prefix: $expected_prefix" >&2
    exit 1
  fi

  if rageveil show "$target_key" >/dev/null 2>&1; then
    local existing_payload
    existing_payload=$(rageveil show "$target_key")
    if [[ -n "$expected_prefix" && "$existing_payload" != "$expected_prefix"* ]]; then
      echo "rageveil key exists with the wrong token type: $target_key" >&2
      echo "expected prefix: $expected_prefix" >&2
      echo "delete it with: rageveil delete $target_key" >&2
      exit 1
    fi
    echo "rageveil key already exists: $target_key" >&2
    echo "not overwriting; update it manually if needed" >&2
    return
  fi

  rageveil insert "$target_key" --payload "$payload"
  echo "inserted $target_key from $source_path"
}

insert_google_oauth_key() {
  local source_path="$1"
  local client_id_source_path="$2"
  local client_secret_source_path="$3"

  local payload
  local source_description
  if [[ -n "$source_path" ]]; then
    if [[ ! -r "$source_path" ]]; then
      echo "cannot read Google OAuth client secrets JSON from $source_path" >&2
      exit 1
    fi

    payload=$(<"$source_path")
    source_description="$source_path"
  elif [[ -r "$client_id_source_path" || -r "$client_secret_source_path" ]]; then
    if [[ ! -r "$client_id_source_path" ]]; then
      echo "cannot read Google OAuth client ID from $client_id_source_path" >&2
      exit 1
    fi
    if [[ ! -r "$client_secret_source_path" ]]; then
      echo "cannot read Google OAuth client secret from $client_secret_source_path" >&2
      exit 1
    fi

    local client_id
    local client_secret
    client_id=$(<"$client_id_source_path")
    client_secret=$(<"$client_secret_source_path")
    if [[ -z "$client_id" ]]; then
      echo "Google OAuth client ID at $client_id_source_path is empty" >&2
      exit 1
    fi
    if [[ -z "$client_secret" ]]; then
      echo "Google OAuth client secret at $client_secret_source_path is empty" >&2
      exit 1
    fi

    payload=$(jq -n \
      --arg client_id "$client_id" \
      --arg client_secret "$client_secret" \
      '{
        installed: {
          client_id: $client_id,
          client_secret: $client_secret,
          auth_uri: "https://accounts.google.com/o/oauth2/auth",
          token_uri: "https://oauth2.googleapis.com/token",
          redirect_uris: [
            "http://localhost",
            "http://127.0.0.1:8723"
          ]
        }
      }')
    source_description="$client_id_source_path and $client_secret_source_path"
  else
    return
  fi

  if ! validate_google_oauth_json <<<"$payload"; then
    echo "Google OAuth client secrets JSON must contain installed.client_id/client_secret or web.client_id/client_secret" >&2
    exit 1
  fi

  if rageveil show "$google_oauth_target_key" >/dev/null 2>&1; then
    local existing_payload
    existing_payload=$(rageveil show "$google_oauth_target_key")
    if ! validate_google_oauth_json <<<"$existing_payload"; then
      echo "rageveil key exists but is not valid Google OAuth client secrets JSON: $google_oauth_target_key" >&2
      echo "delete it with: rageveil delete $google_oauth_target_key" >&2
      exit 1
    fi
    echo "rageveil key already exists: $google_oauth_target_key" >&2
    echo "not overwriting; update it manually if needed" >&2
    return
  fi

  rageveil insert "$google_oauth_target_key" --payload "$payload"
  echo "inserted $google_oauth_target_key from $source_description"
}

sync_authenticated_email_accounts() {
  local account_list="$mirror_data_dir/email_accounts.txt"

  mkdir -p "$mirror_data_dir"
  touch "$account_list"

  local credentials_path
  local account
  shopt -s nullglob
  for credentials_path in "$mirror_data_dir"/accounts/*/credentials.json; do
    account=$(basename "$(dirname "$credentials_path")")
    if ! grep -qxF "$account" "$account_list"; then
      printf '%s\n' "$account" >>"$account_list"
      echo "added $account to $account_list"
    fi
  done
  shopt -u nullglob
}

run_google_email_auth() {
  if [[ "$google_email_auth" != "1" ]]; then
    return
  fi

  if ! command -v mirror_cli >/dev/null 2>&1; then
    echo "mirror_cli is not on PATH; skipping Google email-auth" >&2
    return
  fi

  sync_authenticated_email_accounts

  shopt -s nullglob
  local existing_credentials=("$mirror_data_dir"/accounts/*/credentials.json)
  shopt -u nullglob
  if (( ${#existing_credentials[@]} > 0 )) && [[ "$force_google_email_auth" != "1" ]]; then
    echo "Google account credentials already exist under $mirror_data_dir/accounts" >&2
    echo "not rerunning browser auth; set FORCE_GOOGLE_EMAIL_AUTH=1 to re-auth" >&2
    return
  fi

  echo "starting Google email auth with mirror_cli"
  mirror_cli --data-dir "$mirror_data_dir" email-auth
  sync_authenticated_email_accounts
}

if ! command -v rageveil >/dev/null 2>&1; then
  echo "rageveil is not on PATH" >&2
  echo "run this from a shell with rageveil available" >&2
  exit 1
fi

if [[ ! -e "$store_path/config.json" ]]; then
  if [[ ! -r "$identity_path" ]]; then
    echo "cannot read rageveil identity from $identity_path" >&2
    echo "set RAGEVEIL_IDENTITY to override the identity path" >&2
    exit 1
  fi

  echo "initializing local rageveil store at $store_path"
  rageveil init --identity "$identity_path"
fi

insert_key "Linear API key" "$linear_source_path" "$linear_target_key"
insert_key "Slack bot token" "$slack_source_path" "$slack_target_key" "xoxb-"
insert_google_oauth_key "$google_oauth_source_path" "$google_client_id_source_path" "$google_client_secret_source_path"
run_google_email_auth
