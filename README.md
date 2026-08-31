#  Bloom VNDS Interpreter

<div align="center">

[![Platform: PSP](https://img.shields.io/badge/Platform-PSP-blue.svg?style=for-the-badge&logo=playstationportable)](https://www.playstation.com/)
[![Engine: VNDS Lua](https://img.shields.io/badge/Engine-VNDS%20Lua-purple.svg?style=for-the-badge&logo=lua)](https://www.lua.org/)
[![Status: Active](https://img.shields.io/badge/Status-Active%20&%20Optimized-success.svg?style=for-the-badge)]()

**Maintained & Engineered by iamfeelingbad**

</div>

---

## 🖼️ Showcase & Gallery / Галерея

<div align="center">

### 🌟 Project Logo
<img src="bloom vnds logo transparent.png" alt="Bloom VNDS Logo" width="600"/>

### 🎮 XMB / Launcher Menu Interface
<img src="bloom vnds menu.png" alt="Bloom VNDS Menu" width="700"/>

### 🌸 Narcissu Russian Edition (Demonstration)
<img src="bloom vnds narcissu demonstration.png" alt="Narcissu Demonstration" width="700"/>

### ❓ The Question / Visual Novel Showcase
<img src="bloom vnds the question demonstration.png" alt="The Question Demonstration" width="700"/>

</div>

---

## 📖 About / О проекте

Welcome to the definitive **Bloom VNDS Interpreter** for the PlayStation Portable (PSP). This project delivers an ultra-smooth, highly optimized Lua-based VNDS runtime environment designed to run complex visual novels with custom dashboard themes, advanced audio routing, robust configuration management, and full localized Russian script support.

> *"Bringing immersive storytelling to the PSP with uncompromising performance and elegance."* — **iamfeelingbad**

---

## ✨ Key Features & Improvements

- 🚀 **Direct Startup (`launchermode`):** Toggle launcher mode in config. When disabled (`launchermode=0`), the engine immediately bypasses the XMB menu and boots your chosen visual novel (`defaultnovel`) instantly. When exiting the novel via Main Menu, it cleanly restarts or exits.
- 🎨 **Full Menu Customization:** Tailor the UI appearance to your exact liking. Switch color themes, adjust dialog box alpha transparency, customize border accents, scale fonts (`fontScale`), and toggle text shadows on the fly.
- 🛠️ **Developer Mode (`devmode`):** Enable deep diagnostic tracing. When `devmode=1`, all music requests (`music`, `sound`), channel allocations, and interpreter script steps (`STEP [file:pc]`) are logged in real-time to `vnds_audio.log`.
- 📜 **Advanced Chapter Menu & Scrolling:** Handles long multi-chapter choices (such as 9+ chapters in *Narcissu*) with built-in vertical scrolling and indicator arrows (`▲` / `▼`).
- 🇷🇺 **Russian Localization:** Full support for Cyrillic dialogue rendering, translated game menus, and translated chapter structures.

---

## ⚙️ Configuration Guide (`novels/config.vnds`)

Configure your PSP experience precisely using `novels/config.vnds`:

```ini
# Launcher Mode: 1 = Enabled (shows menu), 0 = Disabled (direct boot)
launchermode=0

# Default Novel to launch when launchermode=0
defaultnovel=Saya no Uta

# Developer Mode logging: 1 = Enabled, 0 = Disabled
devmode=1

# Interface & Reading Preferences
language=ru
theme=1
fontScale=1.25
textColor=1
textShadow=1
boxAlpha=180
```

---

## 🛠️ Controls & Shortcuts

| PSP Button | Action / Shortcut |
| :--- | :--- |
| **Cross (✕)** | Advance text / Confirm selection |
| **Circle (○)** | Back / Cancel / Skip |
| **Select** | Open In-Game Pause Menu (Save / Load / Main Menu) |
| **Triangle (△)** | Quick Return to Launcher / Exit |
| **Square (□)** | Open Dialogue Backlog / History |
| **L-Trigger** | Quick Load Menu |
| **D-Pad / L&R** | Navigate choices and settings |

---

## 📜 Credits & Acknowledgements

- **Core Architecture & Engine:** Bloom VNDS / Digital Haze / Insani
- **Adaptation, Custom Features & Maintenance:** **iamfeelingbad**
- **Localization:** Insani Russian Team
