# preview.yazi

Preview image/video/pdf/archive/ipynb/so/sqlite/svg/docx/xlsx/svg/dex/... on [Yazi](https://github.com/sxyazi/yazi) written in Bash.

<video src="https://github.com/Urie96/preview.yazi/assets/43716456/ab45afad-2068-4e61-8599-65f9d99fe73f"></video>

## Installation

```sh
# Linux/macOS
git clone https://github.com/Urie96/preview.yazi.git ~/.config/yazi/plugins/preview.yazi

# Windows is unsupported
```

## Usage

Add this to your `yazi.toml`:

```toml
[[plugin]]
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
