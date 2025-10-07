# 🛡️ repoauth.sh

**repoauth.sh** is a secure, portable Bash utility for setting up SSH authentication to Git repositories (GitHub, GitLab, or any SSH‑based host).

It lets you interactively provide a Git SSH URL and a private key (pasted or stdin), then automatically:

- 🔐 Writes the key safely under `~/.ssh` with `600` permissions  
- 🧩 Adds or updates a proper `~/.ssh/config` `Host` entry  
- 🪣 Logs operations through `systemd-journald` (if available)  
- 🧠 Validates inputs, permissions, and exits cleanly with error handling  
- 🧬 100% ShellCheck‑clean and works on **any Linux distro**

---

## 🚀 Quickstart (One‑liner)

Run directly from GitHub with `wget`:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/Paul1404/repoauth.sh/main/repoauth.sh)
```

> 💡 You’ll be prompted for the repo SSH address and private key interactively.  
> The script will configure everything securely in `~/.ssh/`.

---

## 🧩 Example session

```text
$ bash repoauth.sh

=== repoauth: Secure Git SSH Auth Setup ===
Works for any Git SSH host (GitHub, GitLab, custom).

Enter Git SSH repo URL (e.g. git@github.com:user/repo.git): git@github.com:pauldresch/private-repo.git
Paste your private SSH key below. Press Ctrl+D when done.
⚠️ The key will be saved with strict 600 permissions.
----------------------------------------------------------------
[... you paste your key ...]

✔ SSH key configuration complete for host: github.com

You can now use this alias:
  git clone github.com-repoauth:user/private-repo.git
```

---

## 🧰 Features

- **Secure by default** — strict permissions, no key echoing  
- **Systemd logging** — view logs with `journalctl -t repoauth`  
- **Fails fast** — strong input validation and informative error handling  
- **Self‑contained** — no dependencies beyond `bash`, `sed`, `ssh`, `chmod`, and `mkdir`  
- **Cross‑distro compatible** — works seamlessly on RHEL, Debian, Ubuntu, Fedora, SUSE, Arch, etc.  
- **Readable & maintainable** — fully ShellCheck‑compliant and cleanly structured

---

## 🧾 Requirements

- Linux system with:
  - `bash` 4.x or newer  
  - `sed`, `chmod`, `ssh`, `mkdir`  
  - Optional: `systemd-journald` for logging  
- A valid SSH private key (OpenSSH format)

---

## 🧰 Removing a Key & Config Entry

To revoke access for a host:

```bash
rm -f ~/.ssh/repoauth-<hostname>.key
sed -i '/Host <hostname>-repoauth/,/^$/d' ~/.ssh/config
```

Or add the soon‑to‑come `--remove <host>` feature.

---

## 📖 License

MIT License © 2025 Paul Dresch  
Use, modify, and distribute freely — just don’t forget to `chmod 600`.

---

## 🪶 Logging

To view run logs:

```bash
journalctl -t repoauth
```
