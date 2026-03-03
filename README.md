<p align="center">
  <img src="https://img.shields.io/badge/Shell-Bash-1f425f?style=for-the-badge&logo=gnubash&logoColor=white" />
  <img src="https://img.shields.io/badge/OS-Debian%20%7C%20macOS-A81D33?style=for-the-badge&logo=debian&logoColor=white" />
  <img src="https://img.shields.io/badge/Infra-Proxmox%20%7C%20Docker-E57000?style=for-the-badge&logo=proxmox&logoColor=white" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" />
</p>

<h1 align="center">⚡ Scripts & Runbooks</h1>

<p align="center">
  <i>Battle-tested scripts, configurations, and runbooks I use daily.<br/>
  From bare-metal Proxmox setups to Docker stacks and VPN gateways — all in one place.</i>
</p>

---

## 🗺️ Repository Map

```
scripts/
├── debian/                       # Debian / Ubuntu server scripts
│   ├── iptables-reset.sh         # Safe iptables flush & reset
│   ├── iptables-vpn-gateway.sh   # Turn a server into a VPN gateway (NAT)
│   ├── postgresql.sh             # Interactive PostgreSQL installer (14/16/18)
│   ├── swanctl-l2tp-psk.sh       # L2TP/IPsec split-tunnel VPN client
│   ├── unrar.sh                  # Enable non-free unrar on Debian
│   ├── mqtt-broker.md            # Mosquitto MQTT broker setup guide
│   ├── dockers/                  # Docker Compose stacks
│   │   ├── compreface/           # AI facial recognition service
│   │   ├── frigate/              # NVR with real-time object detection
│   │   └── viseron/              # AI-powered NVR alternative
│   └── proxmox/                  # Proxmox VE guides
│       ├── docker-lxc.md         # Run Docker inside LXC containers
│       ├── homeassistant.md      # Home Assistant VM setup
│       ├── nvidia-disable-nouveau.md  # Disable Nouveau for GPU passthrough
│       └── nvidia-trixie.md      # NVIDIA drivers on Debian Trixie
└── macos/                        # macOS utilities
    └── dns_flush.sh              # Flush DNS cache
```

---

## 📦 What's Inside

### 🐧 Debian / Linux

| Script | Description | Use Case |
|:-------|:------------|:---------|
| [`iptables-reset.sh`](debian/iptables-reset.sh) | Safely flush & reset all iptables rules without SSH lockout | 🔥 Emergency firewall recovery |
| [`iptables-vpn-gateway.sh`](debian/iptables-vpn-gateway.sh) | Configure a Linux server as a VPN gateway with NAT & IP forwarding | 🌐 Route traffic through VPN from other machines |
| [`postgresql.sh`](debian/postgresql.sh) | Interactive installer for PostgreSQL 14, 16, or 18 with HBA & locale configuration | 🗄️ Fresh DB server setup |
| [`swanctl-l2tp-psk.sh`](debian/swanctl-l2tp-psk.sh) | Automated L2TP/IPsec split-tunnel client using modern `swanctl` (no legacy daemons) | 🔒 Site-to-site VPN connection |
| [`unrar.sh`](debian/unrar.sh) | Enable Debian non-free repos and install proprietary `unrar` | 📂 Extract RAR archives |
| [`mqtt-broker.md`](debian/mqtt-broker.md) | Step-by-step Mosquitto MQTT broker with password auth | 🏠 IoT / Home Automation messaging |

---

### 🐳 Docker Stacks

Pre-configured `docker-compose` stacks for AI-powered surveillance and recognition:

| Stack | Description | Key Tech |
|:------|:------------|:---------|
| [`compreface/`](debian/dockers/compreface/) | AI facial recognition & verification service | CompreFace, PostgreSQL |
| [`frigate/`](debian/dockers/frigate/) | Real-time NVR with object detection (persons, cars, animals) | Frigate, Coral TPU, FFmpeg |
| [`viseron/`](debian/dockers/viseron/) | AI-powered NVR alternative with flexible configuration | Viseron, NVIDIA GPU |

---

### 🖥️ Proxmox VE

Guides for configuring Proxmox Virtual Environment and GPU passthrough:

| Guide | Description |
|:------|:------------|
| [`docker-lxc.md`](debian/proxmox/docker-lxc.md) | Run Docker inside unprivileged LXC containers |
| [`homeassistant.md`](debian/proxmox/homeassistant.md) | Home Assistant OS VM installation step-by-step |
| [`nvidia-disable-nouveau.md`](debian/proxmox/nvidia-disable-nouveau.md) | Blacklist Nouveau driver for NVIDIA GPU passthrough |
| [`nvidia-trixie.md`](debian/proxmox/nvidia-trixie.md) | Install NVIDIA proprietary drivers on Debian Trixie |

---

### 🍎 macOS

| Script | Description |
|:-------|:------------|
| [`dns_flush.sh`](macos/dns_flush.sh) | Flush DNS cache (`dscacheutil` + `mDNSResponder`) |

---

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/brunoguirado/scripts.git
cd scripts

# Run any script (example: PostgreSQL installer)
sudo bash debian/postgresql.sh

# Or just copy a one-liner (example: macOS DNS flush)
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

> [!IMPORTANT]
> Most Debian scripts require **root privileges**. Always review scripts before running with `sudo`.

---

## 🧭 Philosophy

- **📖 Document everything** — If I had to Google it twice, it deserves a script.
- **🔁 Idempotent when possible** — Scripts use guard clauses (e.g., `iptables -C` checks) to avoid duplicate rules.
- **🛡️ Safety first** — Critical scripts set default policies to `ACCEPT` before flushing to prevent lockouts.
- **🧩 Modular** — Each script is self-contained. No hidden dependencies between them.

---

## 🤝 Contributing

Found a bug or have a useful script to share? Feel free to open an issue or submit a PR.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

<p align="center">
  <sub>Made with ☕ by <a href="https://github.com/brunoguirado">@brunoguirado</a></sub>
</p>
