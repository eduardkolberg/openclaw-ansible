#!/bin/bash
# Bootstrap OpenClaw installation from eduardkolberg's fork.
#
# Run this on the server as root:
#   curl -sSL https://raw.githubusercontent.com/eduardkolberg/openclaw-ansible/main/install_fork.sh | bash
#
# Or after cloning:
#   bash install_fork.sh [branch]
#
# Rollback: git -C /opt/openclaw-ansible checkout <commit-or-tag> && cd /opt/openclaw-ansible && ./run-playbook.sh

set -e

FORK_REPO="https://github.com/eduardkolberg/openclaw-ansible.git"
FORK_BRANCH="${1:-main}"
INSTALL_DIR="/opt/openclaw-ansible"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
fail() { echo -e "${RED}[✗]${NC} $*"; exit 1; }

# OS check
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        fail "Unsupported OS: $ID. Only Ubuntu/Debian are supported."
    fi
else
    fail "Cannot detect OS. Only Ubuntu/Debian are supported."
fi

# Root check
if [ "$EUID" -ne 0 ]; then
    fail "This script must be run as root."
fi

log "Installing system dependencies..."
apt-get update -q
apt-get install -y ansible git

log "Ansible version: $(ansible --version | head -1)"
log "Git version: $(git --version)"

# Clone or update the fork
if [ -d "$INSTALL_DIR/.git" ]; then
    warn "Directory $INSTALL_DIR already exists — pulling latest changes..."
    git -C "$INSTALL_DIR" fetch origin
    git -C "$INSTALL_DIR" checkout "$FORK_BRANCH"
    git -C "$INSTALL_DIR" pull origin "$FORK_BRANCH"
else
    log "Cloning fork: $FORK_REPO (branch: $FORK_BRANCH)"
    git clone -b "$FORK_BRANCH" "$FORK_REPO" "$INSTALL_DIR"
fi

cd "$INSTALL_DIR"

log "Current commit: $(git log --oneline -1)"

log "Installing Ansible collections..."
ansible-galaxy collection install -r requirements.yml --force

log "Running openclaw playbook..."
./run-playbook.sh

log ""
log "Fork repo is at: $INSTALL_DIR"
log "To rollback to a previous version:"
log "  git -C $INSTALL_DIR log --oneline -10"
log "  git -C $INSTALL_DIR checkout <commit>"
log "  cd $INSTALL_DIR && ./run-playbook.sh"
