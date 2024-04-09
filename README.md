# preview.yazi

Preview image/video/pdf/archive/ipynb/so/sqlite/svg/docx/xlsx/dex/dmg/ipa/apk/ttf/woff/... on [Yazi](https://github.com/sxyazi/yazi) written in Bash.

<video src="https://github.com/Urie96/preview.yazi/assets/43716456/ab45afad-2068-4e61-8599-65f9d99fe73f"></video>

<img width="960" alt="20240409205847" src="https://github.com/Urie96/preview.yazi/assets/43716456/65554b40-b459-491a-9b69-9d3ee4de100a">
<img width="960" alt="20240409205415" src="https://github.com/Urie96/preview.yazi/assets/43716456/04a8e55a-2e92-416b-8311-697552abe50c">
<img width="960" alt="20240409205637" src="https://github.com/Urie96/preview.yazi/assets/43716456/583a5269-46c1-4982-b562-bc2d51e738c3">
<img width="960" alt="20240409205748" src="https://github.com/Urie96/preview.yazi/assets/43716456/49e6cc45-095e-43ea-9047-2fdea727ee4b">

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
  glow imagemagick pandoc sqlite smali miller transmission-cli woff2 # optional in this line
pipx install nbconvert xlsx2csv # optional

# Arch Linux
sudo pacman -S --needed bat ffmpegthumbnailer unarchiver poppler perl-image-exiftool tree \
  glow imagemagick pandoc-bin sqlite smali miller android-tools transmission-cli catdoc docx2txt woff2 # optional in this line
pipx install nbconvert xlsx2csv # optional

# Ubuntu/Debian
sudo apt install bat ffmpegthumbnailer unar poppler-utils exiftool tree \
  glow imagemagick pandoc sqlite miller transmission-cli catdoc docx2txt woff2 # optional in this line
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
