#!/usr/bin/env bash
# ==============================================================================
# Check-Node-Troubleshooting — Node Remote Health Agent & Self-Healing Daemon
# ==============================================================================

set -u

NODE_STATUS_FILE="/tmp/node_status.json"
LEMONADE_URL="${LEMONADE_URL:-http://localhost:13305/v1/models}"
LOG_FILE="Node-Troubleshooting-error.md"

# Function: Generate Health Report
get_health_json() {
    export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.hermes/bin:$HOME/.hermes/hermes-agent/bin:$HOME/.npm-global/bin:$PATH"

    local docker_ok=false
    local lemonade_ok=false
    local model_ok=false
    local opencode_config_ok=false

    docker info &>/dev/null && docker_ok=true
    curl -s "$LEMONADE_URL" &>/dev/null && lemonade_ok=true
    curl -s "$LEMONADE_URL" 2>/dev/null | grep -iq "Qwen" && model_ok=true
    [ -f "$HOME/.config/opencode/config.json" ] && opencode_config_ok=true

    cat << EOF
{
  "hostname": "$(hostname)",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "docker_daemon": $docker_ok,
  "lemonade_server": $lemonade_ok,
  "qwen_model_loaded": $model_ok,
  "opencode_config": $opencode_config_ok
}
EOF
}

# Function: Log Node Error with Metadata (Date, Hostname, User)
log_error() {
    local err_msg="${1:-Unspecified error}"
    local do_push="${2:-}"
    local date_iso="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    local date_human="$(date +"%Y-%m-%d %H:%M:%S %Z")"
    local node_host="$(hostname)"
    local current_user="${USER:-$(whoami)}"

    # Determine log file path (prefer current directory, fallback to documentation/)
    if [ ! -f "$LOG_FILE" ] && [ -f "documentation/Node-Troubleshooting-error.md" ]; then
        LOG_FILE="documentation/Node-Troubleshooting-error.md"
    fi

    if [ ! -f "$LOG_FILE" ]; then
        cat << 'EOF_HEADER' > "$LOG_FILE"
# Node Troubleshooting & Remote Error Logs — Local AI Workstations

Journal centralisé des erreurs rapportées par les nœuds distants.

---

## 📝 Historique des Erreurs Rapportées par les Nœuds

EOF_HEADER
    fi

    cat << EOF_ENTRY >> "$LOG_FILE"

### 🚨 [${date_human}] Node: ${node_host} (User: ${current_user})

* **Date & Heure :** \`${date_iso}\`
* **Machine (Hostname) :** \`${node_host}\`
* **Utilisateur :** \`${current_user}\`
* **Message / Rapport d'Erreur :**
\`\`\`text
${err_msg}
\`\`\`

---
EOF_ENTRY

    echo "[LOG] Erreur consignée dans ${LOG_FILE} pour ${node_host} (${current_user})"

    if [ "$do_push" = "--push" ] || [ "${3:-}" = "--push" ]; then
        echo "[GIT] Publication automatique sur GitHub..."
        git add "$LOG_FILE"
        git commit -m "log: error report from ${node_host} (${current_user})" 2>/dev/null || true
        git push origin main || echo "[GIT WARN] Push échoué — vérifiez l'authentification Git"
    fi
}

# Function: Auto-Fix Identified Errors
auto_fix() {
    echo "=== Auto-Healing Process Started on $(hostname) ==="
    
    # Fix 1: PATH Environment export in ~/.bashrc
    if ! grep -q ".local/bin" "$HOME/.bashrc" 2>/dev/null; then
        echo "[FIX] Adding ~/.local/bin and local AI bin paths to ~/.bashrc..."
        echo 'export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.hermes/bin:$HOME/.hermes/hermes-agent/bin:$HOME/.npm-global/bin:$PATH"' >> "$HOME/.bashrc"
    fi
    export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.hermes/bin:$HOME/.hermes/hermes-agent/bin:$HOME/.npm-global/bin:$PATH"

    # Fix 2: Docker Daemon
    if ! docker info &>/dev/null; then
        echo "[FIX] Starting Docker service..."
        sudo systemctl enable --now docker 2>/dev/null || true
    fi

    # Fix 3: OpenCode Config
    if [ ! -f "$HOME/.config/opencode/config.json" ]; then
        echo "[FIX] Creating missing ~/.config/opencode/config.json..."
        mkdir -p "$HOME/.config/opencode"
        cat << 'EOF_OC' > "$HOME/.config/opencode/config.json"
{
  "$schema": "https://opencode.ai/config.schema.json",
  "provider": "openai",
  "options": {
    "baseURL": "http://localhost:13305/v1",
    "apiKey": "lemonade",
    "model": "Qwen3-Coder-30B-A3B-Instruct-GGUF"
  },
  "execution": {
    "approval": "auto",
    "timeout": 300
  }
}
EOF_OC
    fi

    # Fix 4: Lemonade Server
    if ! curl -s "$LEMONADE_URL" &>/dev/null; then
        echo "[FIX] Restarting Lemonade service..."
        sudo systemctl restart lemonade.service 2>/dev/null || true
    fi

    # Fix 5: OpenCode CLI Installation
    if ! command -v opencode &>/dev/null && [ ! -f "$HOME/.local/bin/opencode" ] && [ ! -f "$HOME/.opencode/bin/opencode" ]; then
        echo "[FIX] Installing OpenCode CLI..."
        curl -fsSL https://opencode.ai/install.sh | bash 2>/dev/null || npm i -g opencode-ai 2>/dev/null || true
    fi

    # Fix 6: Hermes Agent CLI Installation
    if ! command -v hermes &>/dev/null && [ ! -f "$HOME/.local/bin/hermes" ] && [ ! -f "$HOME/.hermes/hermes-agent/bin/hermes" ]; then
        echo "[FIX] Installing Hermes Agent CLI..."
        curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash 2>/dev/null || true
    fi

    echo "=== Auto-Healing Process Complete ==="
}

# CLI Arguments Handling
case "${1:-status}" in
    --status|status)
        get_health_json
        ;;
    --fix|fix)
        auto_fix
        ;;
    --log-error|log-error)
        log_error "${2:-"Erreur non spécifiée"}" "${3:-}"
        ;;
    --daemon|daemon)
        echo "Starting Node Agent Daemon..."
        while true; do
            get_health_json > "$NODE_STATUS_FILE"
            sleep 30
        done
        ;;
    --opencode|--opencode-status|opencode)
        shift
        if [ -f "$(dirname "$0")/check-opencode-status.py" ]; then
            python3 "$(dirname "$0")/check-opencode-status.py" "$@"
        elif command -v check-opencode-status.py &>/dev/null; then
            check-opencode-status.py "$@"
        else
            echo "[ERROR] check-opencode-status.py non trouvé."
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 [--status | --fix | --opencode [--watch] | --log-error \"message\" [--push] | --daemon]"
        exit 1
        ;;
esac
