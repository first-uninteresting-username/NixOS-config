# Usage: t3code-tunnel-setup <hostname> <tunnel-host-name>
# Run from the repository root. Reads the API token and the allowed email from the terminal.
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: t3code-tunnel-setup <hostname> <tunnel-host-name>" >&2
  exit 2
fi
hostname=$1
tunnelName="t3code-$2"
secretsFile=secrets/secrets.yaml
secretKey='["cloudflared_t3code_token"]'
origin=http://localhost:3773

if [ ! -f "$secretsFile" ]; then
  echo "Run this from the repository root: $secretsFile not found." >&2
  exit 1
fi

read -rsp "Cloudflare API token: " apiToken
echo
read -rp "Email address Cloudflare Access allows: " email
[ -n "$apiToken" ] && [ -n "$email" ] || {
  echo "Both values are required." >&2
  exit 1
}
# Ask for the sudo password now rather than after the tunnel exists.
sudo -v

# Passes the token through a curl config file descriptor to keep it out of process listings.
cf() {
  local method=$1 path=$2 response
  local args=(-sS -X "$method" -H 'Content-Type: application/json')
  [ $# -lt 3 ] || args+=(--data "$3")
  response=$(curl "${args[@]}" "https://api.cloudflare.com/client/v4$path" \
    -K <(printf 'header = "Authorization: Bearer %s"\n' "$apiToken"))
  if [ "$(jq -r .success <<<"$response")" != true ]; then
    echo "Cloudflare refused $method $path:" >&2
    jq -c '.errors' <<<"$response" >&2
    exit 1
  fi
  jq -c .result <<<"$response"
}

# The zone is the hostname minus its first label.
zoneName=${hostname#*.}
zone=$(cf GET "/zones?name=$zoneName" | jq -c '.[0] // empty')
[ -n "$zone" ] || {
  echo "No zone $zoneName is visible to this token." >&2
  exit 1
}
zoneId=$(jq -r .id <<<"$zone")
accountId=$(jq -r .account.id <<<"$zone")

tunnelId=$(cf GET "/accounts/$accountId/cfd_tunnel?name=$tunnelName&is_deleted=false" |
  jq -r '.[0].id // empty')
if [ -n "$tunnelId" ]; then
  echo "Reusing tunnel $tunnelName ($tunnelId)."
else
  tunnelId=$(cf POST "/accounts/$accountId/cfd_tunnel" \
    "$(jq -nc --arg n "$tunnelName" '{name: $n, config_src: "cloudflare"}')" | jq -r .id)
  echo "Created tunnel $tunnelName ($tunnelId)."
fi

cf PUT "/accounts/$accountId/cfd_tunnel/$tunnelId/configurations" "$(
  jq -nc --arg h "$hostname" --arg o "$origin" \
    '{config: {ingress: [{hostname: $h, service: $o}, {service: "http_status:404"}]}}'
)" >/dev/null
echo "Routed $hostname to $origin."

# Gate the hostname with Access before DNS points at the tunnel.
accessApp=$(jq -nc --arg h "$hostname" --arg e "$email" '{
  name: "T3 Code", domain: $h, type: "self_hosted", session_duration: "24h",
  policies: [{name: "Owner", decision: "allow", include: [{email: {email: $e}}]}]
}')
appId=$(cf GET "/accounts/$accountId/access/apps" |
  jq -r --arg h "$hostname" 'map(select(.domain == $h)) | .[0].id // empty')
if [ -n "$appId" ]; then
  cf PUT "/accounts/$accountId/access/apps/$appId" "$accessApp" >/dev/null
else
  cf POST "/accounts/$accountId/access/apps" "$accessApp" >/dev/null
fi
echo "Cloudflare Access allows only $email on $hostname."

record=$(jq -nc --arg h "$hostname" --arg c "$tunnelId.cfargotunnel.com" \
  '{type: "CNAME", name: $h, content: $c, proxied: true, comment: "T3 Code tunnel"}')
recordId=$(cf GET "/zones/$zoneId/dns_records?name=$hostname" | jq -r '.[0].id // empty')
if [ -n "$recordId" ]; then
  cf PUT "/zones/$zoneId/dns_records/$recordId" "$record" >/dev/null
else
  cf POST "/zones/$zoneId/dns_records" "$record" >/dev/null
fi
echo "Pointed $hostname at the tunnel."

# sops expects a JSON-encoded value; stdin keeps the token out of process listings.
cf GET "/accounts/$accountId/cfd_tunnel/$tunnelId/token" |
  sudo sops-easy set --value-stdin "$secretsFile" "$secretKey"
echo "Wrote the tunnel token to $secretsFile under $secretKey."
echo "Commit it and deploy the host. Revoke the API token if nothing else needs it."
