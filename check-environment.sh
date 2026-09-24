#!/usr/bin/env bash
# ==============================================================================
# PiratesBayLocalAI — Target Workstation System Environment Checker
# ==============================================================================

set -u

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

# Include common local binary directories in PATH for check
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$HOME/.hermes/bin:$HOME/.hermes/hermes-agent/bin:$HOME/.npm-global/bin:$PATH"

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}   PiratesBayLocalAI — System Pre-Check Script       ${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo ""

# 1. Check Python & Git
echo -n "[CHECK] Python 3 ... "
if command -v python3 &>/dev/null; then
    echo -e "${GREEN}OK${NC} ($(python3 --version))"
else
    echo -e "${RED}FAIL${NC} (python3 not installed)"
    ((ERRORS++))
fi

echo -n "[CHECK] Git ... "
if command -v git &>/dev/null; then
    echo -e "${GREEN}OK${NC} ($(git --version))"
else
    echo -e "${RED}FAIL${NC} (git not installed)"
    ((ERRORS++))
fi

# 2. Check Docker Engine & Docker Compose
echo -n "[CHECK] Docker Engine Daemon ... "
if command -v docker &>/dev/null && docker info &>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAIL${NC} (Docker not installed or daemon not running / permissions missing)"
    ((ERRORS++))
fi

echo -n "[CHECK] Docker Compose ... "
if docker compose version &>/dev/null; then
    echo -e "${GREEN}OK${NC} ($(docker compose version | head -n1))"
elif command -v docker-compose &>/dev/null; then
    echo -e "${GREEN}OK${NC} ($(docker-compose --version))"
else
    echo -e "${RED}FAIL${NC} (docker compose not available)"
    ((ERRORS++))
fi

# 3. Check LLM Inference Server (Lemonade / vLLM)
LEMONADE_URL="${LEMONADE_URL:-http://localhost:13305/v1/models}"
echo -n "[CHECK] LLM Inference Server ($LEMONADE_URL) ... "
HTTP_CODE=$(curl -s -o /tmp/lemonade_models.json -w "%{http_code}" "$LEMONADE_URL" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}OK${NC} (Endpoint reachable)"
    
    echo -n "[CHECK] Qwen Coder Model Presence ... "
    if grep -iq "Qwen" /tmp/lemonade_models.json 2>/dev/null; then
        echo -e "${GREEN}OK${NC} (Model detected)"
    else
        echo -e "${YELLOW}WARN${NC} (Lemonade active, but Qwen Coder model not detected in models list)"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}WARN${NC} (Endpoint unreachable on $LEMONADE_URL — status code: $HTTP_CODE)"
    ((WARNINGS++))
fi
rm -f /tmp/lemonade_models.json

# 4. Check OpenCode & Hermes CLI
echo -n "[CHECK] OpenCode CLI ... "
if command -v opencode &>/dev/null; then
    echo -e "${GREEN}OK${NC} ($(opencode --version 2>/dev/null || echo 'Installed'))"
elif [ -f "$HOME/.local/bin/opencode" ] || [ -f "$HOME/.opencode/bin/opencode" ]; then
    echo -e "${GREEN}OK${NC} (Found in ~/.local/bin or ~/.opencode/bin — PATH update recommended)"
else
    echo -e "${YELLOW}WARN${NC} (opencode CLI not found. Install via: npm i -g opencode-ai or curl -fsSL https://opencode.ai/install.sh | bash)"
    ((WARNINGS++))
fi

echo -n "[CHECK] OpenCode Host Config (~/.config/opencode/config.json) ... "
if [ -f "$HOME/.config/opencode/config.json" ]; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}WARN${NC} (File ~/.config/opencode/config.json missing — run ./node-agent.sh --fix to generate)"
    ((WARNINGS++))
fi

echo -n "[CHECK] Hermes Agent CLI ... "
if command -v hermes &>/dev/null; then
    echo -e "${GREEN}OK${NC} ($(hermes --version 2>/dev/null || echo 'Installed'))"
elif [ -f "$HOME/.local/bin/hermes" ] || [ -f "$HOME/.hermes/hermes-agent/bin/hermes" ]; then
    echo -e "${GREEN}OK${NC} (Found in ~/.local/bin or ~/.hermes — PATH update recommended)"
else
    echo -e "${YELLOW}WARN${NC} (hermes CLI not found. Install via: curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash)"
    ((WARNINGS++))
fi

echo ""
echo -e "${BLUE}=====================================================${NC}"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN} SUCCESS: System fully ready to launch PiratesBayLocalAI!${NC}"
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW} WARNING: System operational with $WARNINGS warning(s). Check messages above.${NC}"
else
    echo -e "${RED} ERROR: System check failed with $ERRORS error(s) and $WARNINGS warning(s). Please resolve required items.${NC}"
fi
echo -e "${BLUE}=====================================================${NC}"
