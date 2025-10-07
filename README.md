# 🛡️ repoauth.sh

**repoauth.sh** is a zero‑nonsense Linux shell utility that configures secure SSH authentication
for any Git host — **GitHub, GitLab, or self‑hosted instances** — the right way.

It lets you paste an SSH private key once and automatically:

- 🔐 Writes it to `~/.ssh/<host>.key` with strict `600` permissions  
- 🧩 Adds a proper `Host <hostname>` block to your `~/.ssh/config`  
- 🪶 Cleans CRLF newlines for copy‑pasted keys  
- 🧠 Verifies directory and file permissions (`700` / `600`)  
- 🧾 Logs actions to both **stderr** and **systemd‑journald**  
- 🧱 Works out of the box on any mainstream Linux distribution

No aliases, no URL parsing, no drama — just a clean SSH experience.

---

## 🚀 Quickstart

Run it directly from GitHub (root or user shell — no install needed):

```bash
bash <(wget -qO- https://raw.githubusercontent.com/Paul1404/repoauth.sh/main/repoauth.sh)
```

or, if your system prefers `curl`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Paul1404/repoauth.sh/main/repoauth.sh)
```

---

## 🧩 Example Session

```text
$ bash repoauth.sh
[2025-10-07 23:59:12] [INFO] Starting repoauth v3.0
Enter Git host (e.g. github.com, gitlab.com, custom.domain): github.com
Paste your private SSH key for this host.
Press Ctrl+D when done.
⚠️ Key will be stored with strict 600 permissions.
-------------------------------------------------------------
[ you paste key here, end with Ctrl+D ]
[INFO] Private key written to /home/user/.ssh/github.com.key
[INFO] Added SSH configuration block for github.com
Test SSH connection to github.com now? [y/N]: y
Hi Paul1404! You've successfully authenticated, but GitHub does not provide shell access.

✅ Setup complete for host: github.com
```

Your SSH now *just works*:

```bash
git clone git@github.com:Paul1404/repoauth.sh.git
```

---

## 🧰 Configuration Result

```text
~/.ssh/config
─────────────────────────────────────────────
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/github.com.key
    IdentitiesOnly yes
```

The corresponding key is stored at:
```
~/.ssh/github.com.key
```

---

## 🧩 Features
| Category | Description |
|-----------|-------------|
| **Security First** | Explicit permissions: `~/.ssh` → 700, keys/config → 600 |
| **Portability** | Pure Bash, works on RHEL, Debian, Ubuntu, Fedora, SUSE, Arch, etc. |
| **Logging** | All actions logged to `stderr` and `journalctl -t repoauth` |
| **Idempotent** | Removes existing host block before writing a new one |
| **Input Sanity** | Strips CRLF newlines; aborts cleanly if input is empty |
| **ShellCheck‑Clean** | Passes ShellCheck with zero warnings |

---

## 🧾 Requirements

- ✅ `bash`, `sed`, `ssh`, `chmod`, `mkdir`
- ✅ Optional: `systemd‑journald` (for richer logs)
- ✅ A copy‑pasteable **OpenSSH‑format private key**

---

## 🪣 Removing a Host

To revoke or replace a key manually:

```bash
rm -f ~/.ssh/<host>.key
sed -i "/Host <host>/,/^$/d" ~/.ssh/config
```

Or re‑run `repoauth.sh` for the same host and choose **“Overwrite”** when prompted.

---

## 🧩 Logging

Inspect past runs:

```bash
journalctl -t repoauth
```

---

## 🛠 Exit Codes

| Code | Meaning |
|------|----------|
| **0** | Success |
| **1** | Missing requirement, invalid input, or user abort |
| **2** | Permission or filesystem failure |

---

## ⚖️ License

MIT License © 2025 Paul Dresch

You’re free to use, modify, and redistribute with credit.
Just don’t forget to `chmod 600 ~/.ssh/*.key`.
