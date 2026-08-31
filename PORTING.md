# 🛠️ Comprehensive VNDS Porting & Adaptation Manual

**Author / Maintainer:** iamfeelingbad  
**Target Platform:** PSP (Bloom VNDS Interpreter / LuaPlayerYT)

---

## 📌 Introduction

This manual provides complete technical specifications for porting, adapting, and structuring visual novels to run on the Bloom VNDS engine for PSP. Adhering to these guidelines ensures 100% compatibility, correct audio playback, and stable rendering.

---

## 📁 Novel Folder Hierarchy

Every novel must be placed in its own folder inside the `novels/` directory:

```text
novels/
└── YourNovelName/
    ├── info.txt           # Metadata (Title & Description)
    ├── icon.png           # 128x128 menu thumbnail icon
    ├── thumbnail.png      # Fallback menu thumbnail
    ├── background/        # Background images (.png, .jpg)
    ├── foreground/        # Character sprites & overlays (.png)
    ├── sound/             # BGM (.mp3 / .ogg) and SFX / Voices (.wav)
    └── script/            # Compiled or plain text VNDS scripts (*.scr)
```

### 1. `info.txt`
```ini
title=Your Visual Novel Title
```

---

## 🎵 Audio Encoding & Codec Requirements (PSP Hardware)

PSP audio handling has specific limitations. Follow these rules strictly to avoid silence or pitch distortion:

### 1. Background Music (BGM)
- **Script Command:** `music filename.mp3` or `music music/filename.mp3`
- **Engine Resolution:** The engine's `audio.resolvePath` automatically checks for sibling **`.ogg`** files whenever `.mp3` or `.aac` is requested.
- **Required OGG Format:**
  - **Sample Rate:** `44100 Hz`
  - **Channels:** `Stereo` (2 channels). *Note: Mono OGG files on BGM Channel 7 play at incorrect pitch/speed.*
  - **Codec:** Ogg Vorbis.

### 2. Sound Effects & Voices (SFX)
- **Script Command:** `sound filename.wav`
- **Required WAV Format:**
  - **Codec:** Uncompressed PCM (Format Code `1`).
  - **Sample Rate:** `44100 Hz` (recommended matching engine standard) or `22050 Hz`.
  - **Channels:** `Mono` (1 channel).
  - **Bit Depth:** `16-bit` little-endian.
  - **Header:** Must contain a valid 44-byte **RIFF/WAVE** header. Headerless raw PCM streams will fail to load and remain silent.

---

## 📜 Script Syntax & Commands (`.scr`)

Scripts are processed line by line. Supported command syntax:

| Command | Syntax Example | Description |
| :--- | :--- | :--- |
| **Background** | `bgload image.png` | Loads and displays background |
| **Text Narration** | `text @Narration line...` | Displays narrator text box |
| **Character Dialogue** | `text Character: Line...` | Displays character dialogue |
| **Clear Text** | `text ~` | Clears text box |
| **Wait for Click** | `text !` | Pauses execution until user presses X |
| **Music Play** | `music music.mp3` | Plays background music |
| **Sound Play** | `sound effect.wav` | Plays sound effect / voice |
| **Choices** | `choice Option A \| Option B` | Displays interactive choice menu |
| **Conditionals** | `if selected == 1 ... fi` | Conditional branch based on variable |
| **Variables** | `setvar var = 1` | Sets local or global variable |
| **Script Jump** | `jump next.scr` | Jumps to another script file |

---

## 🚀 Advanced Deployment & Testing

1. Place your novel folder in `novels/YourNovelName`.
2. Configure `novels/config.vnds`:
   ```ini
   launchermode=0
   defaultnovel=YourNovelName
   devmode=1
   ```
3. Run the PSP emulator or hardware loader. Check `vnds_audio.log` for real-time diagnostic traces of all asset loading and audio events.

---
*Happy porting and developing!* — **iamfeelingbad**
