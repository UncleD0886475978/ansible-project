#!/usr/bin/env bash
# setup.sh — ansible-project (Ansible HomeLab: root site.yml + ansible.cfg + inventory/)
# Safe by design: validates the playbook with --syntax-check only. Nothing is applied to any host.
set -e

REPO="ansible-project"
OWNER="UncleD0886475978"
CLONE_URL="https://github.com/${OWNER}/${REPO}.git"
TARGET_DIR="$HOME/repos/${REPO}"

echo "==> Step 1/5: Locate or clone ${REPO}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d ".git" ] && git remote get-url origin 2>/dev/null | grep -qi "${REPO}"; then
  REPO_DIR="$PWD"
elif [ -d "${SCRIPT_DIR}/.git" ] && git -C "${SCRIPT_DIR}" remote get-url origin 2>/dev/null | grep -qi "${REPO}"; then
  REPO_DIR="${SCRIPT_DIR}"
elif [ -d "${TARGET_DIR}/.git" ]; then
  REPO_DIR="${TARGET_DIR}"
  git -C "${REPO_DIR}" pull --ff-only || echo "    (git pull skipped/failed — continuing with existing checkout)"
else
  if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git is not installed. Install it: https://git-scm.com/downloads"
    exit 1
  fi
  mkdir -p "$HOME/repos"
  git clone "${CLONE_URL}" "${TARGET_DIR}"
  REPO_DIR="${TARGET_DIR}"
fi
cd "${REPO_DIR}"
echo "    Working in: ${REPO_DIR}"

echo "==> Step 2/5: Check prerequisites (python3 for Ansible)"
if ! command -v python3 >/dev/null 2>&1; then
  echo "MISSING: python3 — install from https://www.python.org/downloads/"
  echo "Ansible install docs: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html"
  exit 1
fi
echo "    python3: $(python3 --version)"

echo "==> Step 3/5: Ansible — use system ansible, or a local venv"
ANSIBLE_PLAYBOOK=""
if command -v ansible-playbook >/dev/null 2>&1; then
  ANSIBLE_PLAYBOOK="ansible-playbook"
elif [ -x ".venv/bin/ansible-playbook" ]; then
  ANSIBLE_PLAYBOOK=".venv/bin/ansible-playbook"
else
  echo "    ansible not found — creating .venv and installing ansible with pip..."
  echo "    (Manual alternative: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)"
  python3 -m venv .venv
  .venv/bin/pip install --upgrade pip >/dev/null
  .venv/bin/pip install ansible
  ANSIBLE_PLAYBOOK=".venv/bin/ansible-playbook"
fi
${ANSIBLE_PLAYBOOK} --version | head -n 1

echo "==> Step 4/5: Show the inventory this project will target"
if [ -d inventory ]; then
  find inventory -type f | sort | sed 's/^/    inventory file: /'
  FIRST_INV="$(find inventory -type f | sort | head -n 1)"
  if [ -n "${FIRST_INV}" ]; then
    echo "    Hosts/groups in ${FIRST_INV}:"
    ${ANSIBLE_PLAYBOOK} -i "${FIRST_INV}" --list-hosts site.yml 2>/dev/null | sed 's/^/    /' || echo "    (could not list hosts — check the inventory file by hand)"
  fi
elif [ -f inventory ]; then
  echo "    inventory file: inventory"
else
  echo "    No inventory/ found — playbooks will need an explicit -i <inventory> when run."
fi
if [ -f ansible.cfg ]; then
  echo "    ansible.cfg present — Ansible picks it up automatically in this directory."
fi

echo "==> Step 5/5: Syntax-check the main playbook (does not change any host)"
if [ -f site.yml ]; then
  ${ANSIBLE_PLAYBOOK} --syntax-check site.yml
  echo "    site.yml syntax OK."
else
  echo "    No site.yml at repo root. Playbooks found:"
  find . -name '*.yml' -o -name '*.yaml' | grep -v '.venv' | sort | sed 's/^/      /' || true
fi
echo "    Any other playbooks in the repo:"
find . -name '*.yml' -o -name '*.yaml' | grep -v '.venv' | sort | sed 's/^/      /' || true

cat <<'EOF'

✅ ansible-project verified (playbook syntax-checked, no hosts changed).

NEXT COMMANDS
  Run/use:
    • Dry-run first (recommended):  ansible-playbook site.yml --check
    • Real run against the homelab: ansible-playbook site.yml
      (add -i inventory/<file> if ansible.cfg does not already point at your inventory,
       and --ask-become-pass if your hosts need a sudo password)
  Stop:
    • Nothing runs persistently — a playbook run ends on its own.
      To undo changes, edit/re-run the playbook; there is no daemon to stop.
  Logs:
    • Terminal output of each run (ansible.cfg in this repo controls logging/display settings).
EOF
