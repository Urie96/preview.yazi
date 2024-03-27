# preview.yazi

Preview image/video/pdf/archive/ipynb/so/sqlite/svg/docx/xlsx/svg/dex/... on [Yazi](https://github.com/sxyazi/yazi) written in Bash.

<video src="https://github.com/Urie96/preview.yazi/assets/43716456/ab45afad-2068-4e61-8599-65f9d99fe73f"></video>

## Requirements

- [Yazi](https://github.com/sxyazi/yazi) v0.2.4+

## Installation

```sh
# Linux/macOS
git clone https://github.com/Urie96/preview.yazi.git ~/.config/yazi/plugins/preview.yazi

# Windows is unsupported
```

**Dependencies**

```sh
# Mac OS
brew install bat ffmpegthumbnailer unar poppler exiftool tree \
  glow imagemagick pandoc sqlite smali miller transmission-cli # optional in this line
pipx install nbconvert xlsx2csv # optional

# Arch Linux
sudo pacman -S --needed bat ffmpegthumbnailer unarchiver poppler perl-image-exiftool tree \
  glow imagemagick pandoc-cli sqlite smali miller android-tools transmission-cli # optional in this line
pipx install nbconvert xlsx2csv # optional

# Ubuntu/Debian
sudo apt install bat ffmpegthumbnailer unar poppler-utils exiftool tree \
  glow imagemagick pandoc sqlite miller transmission-cli # optional in this line
pipx install nbconvert xlsx2csv # optional
```

## Usage

Add this to your `yazi.toml`:

```toml
[plugin]
previewers = [
  { name = "*/", run = "folder", sync = true },
  { name = "*.md", run = "preview" },
  { name = "*.csv", run = "preview" },
  { mime = "text/*", run = "code" },
  { mime = "*/xml", run = "code" },
  { mime = "*/javascript", run = "code" },
  { mime = "*/x-wine-extension-ini", run = "code" },
  { name = "*", run = "preview" },
]
```
