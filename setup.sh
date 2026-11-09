#!/usr/bin/env bash
# setup.sh — ansible-project (Ansible HomeLab: root site.yml + ansible.cfg + inventory/)
# Safe by design: validates the playbook with --syntax-check only. Nothing is applied to any host.
# Bootstrap: on a fresh Ubuntu/Debian VM this script INSTALLS its own prerequisites
# (git/curl base tools + python3/venv; Ansible itself via a pip venv — never apt).
set -e

REPO="ansible-project"
OWNER="UncleD0886475978"
CLONE_URL="https://github.com/${OWNER}/${REPO}.git"
TARGET_DIR="$HOME/repos/${REPO}"
RUN_ONELINE="curl -fsSL https://raw.githubusercontent.com/${OWNER}/${REPO}/main/setup.sh | bash"

echo "==> Step 1/6: Platform check + base bootstrap (git, curl)"
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "ERROR: this script needs root or sudo to install packages."
    exit 1
  fi
fi
APT=0
if [ "$(uname -s)" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then APT=1; fi
INSTALLED=""
APT_UPDATED=""
note_installed() { INSTALLED="${INSTALLED} $1"; }
apt_update_once() {
  if [ -z "${APT_UPDATED}" ]; then $SUDO apt-get update -y; APT_UPDATED=1; fi
}
apt_install() {
  apt_update_once
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "$@"
}
if [ "${APT}" -eq 1 ]; then
  BASE_PKGS=""
  command -v git >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} git"
  command -v curl >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} curl"
  [ -f /etc/ssl/certs/ca-certificates.crt ] || BASE_PKGS="${BASE_PKGS} ca-certificates"
  command -v gpg >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} gnupg"
  if [ -n "${BASE_PKGS}" ]; then
    echo "    Installing base tools:${BASE_PKGS}"
    # shellcheck disable=SC2086
    apt_install ${BASE_PKGS}
    note_installed "${BASE_PKGS}"
  else
    echo "    Base tools already present (git, curl, ca-certificates, gnupg)."
  fi
else
  echo "    Non-apt platform detected — bootstrap will only CHECK tools and print install guidance."
fi

install_python() {
  if command -v python3 >/dev/null 2>&1 && python3 -c "import venv" >/dev/null 2>&1; then echo "    python3 + venv: already present ($(python3 --version))"; return 0; fi
  [ "${APT}" -eq 1 ] || return 1
  echo "    Installing python3, venv and pip..."
  apt_install python3 python3-venv python3-pip
  note_installed "python3"
}

echo "==> Step 2/6: Locate or clone ${REPO}"
if [ -f "$0" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
  SCRIPT_DIR="$PWD"
fi
if [ -d ".git" ] && command -v git >/dev/null 2>&1 && git remote get-url origin 2>/dev/null | grep -qi "${REPO}"; then
  REPO_DIR="$PWD"
elif [ -d "${SCRIPT_DIR}/.git" ] && command -v git >/dev/null 2>&1 && git -C "${SCRIPT_DIR}" remote get-url origin 2>/dev/null | grep -qi "${REPO}"; then
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

echo "==> Step 3/6: Bootstrap prerequisites (python3 for Ansible)"
MISSING_LIST=""
install_python || MISSING_LIST="${MISSING_LIST} python3(https://www.python.org/downloads/ — Ansible install docs: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)"
if [ -n "${MISSING_LIST}" ]; then
  echo "ERROR: could not auto-install on this platform. Missing:${MISSING_LIST}"
  echo "Install the tool(s) manually, then re-run this script."
  exit 1
fi
echo "    python3: $(python3 --version)"

echo "==> Step 4/6: Ansible — use system ansible, or a local venv"
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

echo "==> Step 5/6: Show the inventory this project will target"
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

echo "==> Step 6/6: Syntax-check the main playbook (does not change any host)"
if [ -f site.yml ]; then
  ${ANSIBLE_PLAYBOOK} --syntax-check site.yml
  echo "    site.yml syntax OK."
else
  echo "    No site.yml at repo root. Playbooks found:"
  find . -name '*.yml' -o -name '*.yaml' | grep -v '.venv' | sort | sed 's/^/      /' || true
fi
echo "    Any other playbooks in the repo:"
find . -name '*.yml' -o -name '*.yaml' | grep -v '.venv' | sort | sed 's/^/      /' || true

cat <<EOF

=================== BOOTSTRAP SUMMARY ===================
Installed during this run:${INSTALLED:- (nothing — all tools were already present)}
Working copy: ${REPO_DIR}
Next time, set up from scratch on any fresh Ubuntu VM with one line:
  ${RUN_ONELINE}
=========================================================
EOF

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
