# ansible-project — BUILD

- **Repo:** `UncleD0886475978/ansible-project` — public, original (not a fork). Described as "Ansible-HomeLab".
- **Stack actually found** (via GitHub connector directory listing of the root):
  - Ansible: `site.yml` (135 B, root — the main playbook), `ansible.cfg`, `inventory/` directory
  - Root: `README.md` (34 B — essentially a title only), `LICENSE`, `.gitignore`
  - No Terraform, no Dockerfile/docker-compose, no Python requirements at root — this is a pure Ansible project.
- **Inspection note:** the connector returned directory listings, not file bodies, and a later call hit GitHub HTTP 429 (rate limit), so the files *inside* `inventory/` and the body of `site.yml`/`ansible.cfg` were not read. `setup.sh` discovers inventory files at runtime and relies on `ansible.cfg` being picked up automatically.

## One-line install (fresh Ubuntu/Debian VM)

```bash
curl -fsSL https://raw.githubusercontent.com/UncleD0886475978/ansible-project/main/setup.sh | bash
```

The script installs its own prerequisites — git/curl base tools and python3 + venv via apt (Ansible itself is installed with pip into a local `.venv`, never via apt) — then locates/clones the repo and validates it. Alternative: clone the repo yourself and run `./setup.sh` from its root, as described below.

## What setup.sh does

0. Platform check + base bootstrap: installs git/curl/ca-certificates/gnupg via apt when missing (on non-apt systems it only checks tools and prints install guidance).
1. Uses the current checkout if its git remote mentions `ansible-project` (or the script sits in the repo root); otherwise clones into `~/repos/ansible-project` (`git pull` if already there).
2. Bootstraps python3 + venv via apt; on a non-apt system without python3 it prints the Python and Ansible install-doc URLs and exits cleanly.
3. Resolves Ansible: system `ansible-playbook` if present, else creates `.venv` and `pip install ansible`.
4. Lists the inventory files under `inventory/` and shows which hosts `site.yml` would target (`--list-hosts`).
5. Runs `ansible-playbook --syntax-check site.yml` — validation only, no host is changed — and lists any other playbooks present.
6. Prints next commands: `--check` dry-run first, then the real run, plus notes on stopping (nothing persistent) and logs (terminal output / `ansible.cfg`).

**Issue it prevents:** running an unvalidated homelab playbook straight against real hosts and breaking them with a syntax or inventory mistake a 5-second check would have caught.
