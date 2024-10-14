#!/usr/bin/env nu

$env.filepath = ""
$env.preview_width = 50
$env.preview_height = 50
$env.preview_offset = 0

def main [
  --path: string
  --width: int
  --height: int
  --offset: int
] {
  $env.filepath = $path
  $env.preview_width = $width
  $env.preview_height = $height
  $env.preview_offset = $offset
  preview-by-extension
  preview-by-mime
  fallback-preview
}

def preview-by-extension [] {
  match ($env.filepath | path parse | get extension | str downcase) {
    mp3 | flac | wav | m4a => {preview-audio}
    json => {bat -l json --theme=TwoDark $env.filepath | print -r}
    pdf => {preview-pdf}
    toml | tmpl | xml | arsc => {bat $env.filepath | print -r}
    md => {with-cache {glow $env.filepath}}
    ipynb => {preview-ipynb}
    dex => {baksmali list class $env.filepath | tree -C --fromfile . | print -r}
    apk => {preview-apk}
    csv => {preview-csv}
    tsv => {preview-tsv}
    xlsx => {preview-xlsx}
    svg => {preview-svg}
    uc! => {with-cache {nc2mp3 --info $env.filepath | bat -l json --theme TwoDark}}
    sqlite3 | sqlite | db => {preview-sqlite}
    so | dylib => {preview-lib}
    torrent => {transmission-show -- $env.filepath | print -r}
    doc => {preview-doc}
    docx | htm | html |xhtml | rtf => {preview-docx}
    epub => {preview-epub}
    plist => {preview-plist}
    icns => {preview-icns}
    ipa => {preview-ipa}
    dmg => {preview-dmg}
    ttf | ttc | otf => {preview-font}
    woff => {preview-woff}
    woff2 => {preview-woff2}
    ansi => {open -r $env.filepath | print}
    cast => {asciinema cat $env.filepath | print}
    raf => {preview-raf}
    7z | rar | ace | alz | arc | arj | bz | bz2 | cab | cpio | deb | gz | jar | lha | lz | lzh | lzma | lzo | rpm | rz | t7z | tar | tbz | tbz2 | tgz | tlz | txz | tz | tzo | war | xpi | xz | z | zip | nds | iso | pkg => {preview-compress}
    _ => {return}
  }
  exit
}

def preview-by-mime [] {
  let mime = (file -bL --mime-type -- $env.filepath)
  if $mime =~ 'archive$|zip$' {
    preview-compress
  } else if $mime =~ '^text|xml$|javascript$' {
    bat $env.filepath | print
  } else if $mime =~ 'json$' {
    bat -l json --theme=TwoDark $env.filepath | print -r
  } else if $mime =~ '^image' {
    preview-image $env.filepath
    show-photo-exiftool $env.filepath | print -r
  } else if $mime =~ '^video' {
    preview-video
  } else if $mime =~ '^audio' {
    preview-audio
  } else if $mime =~ 'pdf$' {
    preview-pdf
  } else if $mime =~ 'x-sharedlib$' {
    preview-lib
  } else if $mime =~ 'x-object$|x-mach-binary$|executable$' {
    preview-exe-deps
  } else if $mime =~ 'sqlite3$' {
    preview-sqlite
  } else if $mime == 'application/octet-stream' {
    let ext = $env.filepath | path parse | get extension | str downcase
    if $ext == "ts" {
      handle-video
    } else {
      return
    }
  } else {
    return
  }
  exit
}

def fallback-preview [] {
  print "----- File Type Classification -----\n\n"
  file -bL $env.filepath | print
  # fallback to display raw text
  print "----- File Strings -----\n\n"
  if (exists-command strings) {
    strings $env.filepath 
    | head -c ($env.preview_width * $env.preview_height) 
  } else {
    head -c 100000 $env.filepath
  }
  | LC_CTYPE=C LANG=C sed 's/[^[:print:]]//g' 
  | str replace -a "\n" " " 
  | fold -w $env.preview_width
  | print
}

def bat --wrapped [
  ...arg: string
] {
  (
    ^bat 
    --color=always
    --paging=never 
    --style=plain
    --wrap=character
    --line-range :5000
    $"--terminal-width=($env.preview_width)"
    ...$arg
  )
}

def exists-command [command: string] {
  which $command | is-not-empty
}

def exiftool --wrapped [
  ...arg: string
] {
  ^exiftool --ExifTool* --Directory --File* --ProfileDescription* ...$arg
}

def show-photo-exiftool [imagepath: string] {
  exiftool '-ImageSize' '-FocalLength' '-FNumber' '-ShutterSpeedValue' '-ISO' '-ExposureBiasValue' '-RawExposureBias' '-DateTimeOriginal' '-*' $imagepath
  | bat -l yaml
}

def preview-photo-exif [] {
  exiftool -ImageSize -FocalLength -FNumber -ShutterSpeedValue -ISO -ExposureBiasValue -RawExposureBias -DateTimeOriginal '-*' $env.filepath | bat -l yaml | print -r
}

def preview-image [imagepath: string] {
  $"__preview__image__path__ ($imagepath)
(ansi --escape {fg: '#666666'})─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────(ansi reset)" | print -r
}

def cache-path [
  --ext = ""
  --img
] {
  let ext = (if not $img and $ext == "" {"ansi"} else {$ext})
  let md5 = (ls $env.filepath | first | $"($in.name)-($in.modified | into int)" | hash md5)
  $"($env.TMPDIR? | default "/tmp")/yazi/($md5).($ext)"
}

def with-cache [
  --ext = ""
  --img
  --nostdout
  func: closure
] {
  let cache_path = (cache-path --ext $ext --img=$img)
  if ($env.DEBUG? == "1") or (not ($cache_path | path exists)) {
    do $func $cache_path | if $nostdout {
      ignore
    } else {
      save -r -f $cache_path
    }
  }
  if ($cache_path | path exists) and (ls $cache_path | first | $in.size > 0B) {
    if $img {
      preview-image $cache_path
    } else {
      open $cache_path --raw | print -r
    }
  }
}

def preview-audio [] {
  with-cache --img {
    ^exiftool -b -CoverArt -Picture $env.filepath
  }
    (exiftool -Title -SortName -TitleSort -TitleSortOrder -Artist -SortArtist -ArtistSort -PerformerSortOrder
    -Album -SortAlbum -AlbumSort -AlbumSortOrder -AlbumArtist -SortAlbumArtist -AlbumArtistSort -AlbumArtistSortOrder \
    -Genre -TrackNumber -Year -Duration -SampleRate -AudioSampleRate -AudioBitrate -AvgBitrate -Channels -AudioChannels $env.filepath | bat -l yaml | print -r)
}

def preview-pdf [] {
  with-cache --ext ($env.preview_offset | into string) --img --nostdout {|cache_path|
    pdftoppm -singlefile -jpeg -jpegopt quality=75 -f ($env.preview_offset + 1) $env.filepath | save -r -f $cache_path
    if $env.LAST_EXIT_CODE == 99 {
      exit 3
    }
  }
  print $env.preview_offset
  pdfinfo $env.filepath | bat -l yaml | print
}

def glow [filepath?: string] {
  if (exists-command glow) {
    if $filepath == null {
      ^glow -s dracula -
    } else {
      ^glow -s dracula $env.filepath
    }
  } else {
    open -r $env.filepath
  }
}

def preview-ipynb [] {
  with-cache {
    if (exists-command jupyter-nbconvert) {
      jupyter-nbconvert $env.filepath --to markdown --stdout | glow
    } else if (exists-command nbpreview) {
      nbpreview --no-paging --nerd-font --decorated --no-files --unicode --color --images --color-system=standard --theme=ansi_dark $env.filepath
    } else {
      bat -l json $env.filepath
    }
  }
}

def preview-apk [] {
  if not (cache-path | path exists) {
    let aapt = (
      (which aapt).0?.path? 
      | default (glob $"($env.HOME)/Library/Android/sdk/build-tools/**/aapt").0?
    )
    if $aapt == null {
      return ""
    }
    let dump = (run-external $aapt dump badging $env.filepath)
    if $dump == "" {
      return ""
    }
    let icon_path = ($dump | (parse -r "application: .*icon='([^']*)'").0?.capture0?)
    if $icon_path != null {
      with-cache --img --ext icon {
        unzip -p -j $env.filepath $icon_path
      }
    }
    let package = ($dump | lines | first | parse -r " name='([^']+)'.*versionName='([^']+)'")
    let app_name = ($dump | parse -r "application: .*label='([^']+)'")
    with-cache {
      $"App name: ($app_name.0?.capture0?)\nPackage: ($package.0?.capture0?)\nVersion name: ($package.0?.capture1?)" | bat -l yaml
    }
  } else {
    with-cache --img --ext icon --nostdout {}
    with-cache {}
  }
}

def preview-csv [] {
  with-cache {
    open $env.filepath 
    | first 500 
    | each {preview-table}
    | table -e -i false
  }
}

def preview-tsv [] {
  with-cache {
    open $env.filepath 
    | first 500 
    | each {preview-table}
    | table -e -i false
  }
}

def preview-xlsx [] {
  with-cache {
    open -r $env.filepath | try {
      from xlsx 
      | transpose key val 
      | each {|it|
        $"($it.key):\n($it.val | preview-table | table -e -i false)"
      }
    } catch {
      echo
    }
  }
}

def preview-table [] {
  let src = $in
  match ($src | describe) {
    $t if $t =~ "^record" => {
      $src 
      | transpose key val 
      | update val {|it| $it.val | preview-table} 
      | transpose -r -d
    },
    $t if $t =~ "^table" => {
      mut src = $src
      for $col in ($src | columns) {
        $src = ($src | first ($env.preview_height - 10) | update $col {|it| $it | get $col | preview-table } )
      }
      $src
    },
    $t if $t =~ "^list" => {
      $src | first ($env.preview_height - 10) | each {preview-table}
    },
    $t if $t == "string" => {
      $src | str substring -g ..10
    },
    _ => {
      $src
    }
  }
}

def preview-sqlite [] {
  try {
    let db = (open $env.filepath)
    $db | schema
    | get tables
    | transpose key val
    | each {|tbl|
      [
        $"TABLE (ansi green)($tbl.key)(ansi reset):"
        ($tbl.val | get columns | table -e -i false)
        # ($db | query db $"SELECT * FROM ($tbl.key) LIMIT 1")
        ""
      ] | str join "\n"
    #   $it.val | table -e -i false | print
    #   $"($it.key):\n($it.val | preview-table)"
    }
    | str join "\n"
  } catch {
    sqlite3 $env.filepath .schema | str replace ";" ";\n" | bat -l sql
  } | print
}

def preview-lib [] {
  nm --extern-only $env.filepath e>|ignore | print
}

def preview-doc [] {
  with-cache {process-doc}
}

def process-doc [] {
  if (exists-command docx2txt) {
    docx2txt $env.filepath
  } else if (exists-command textutil) {
    textutil -stdout -cat txt $env.filepath
  }
}

def preview-docx [] {
  with-cache {
    if (exists-command pandoc) {
      pandoc -s -t markdown -- $env.filepath | glow
    } else {
      process-doc
    }
  }
}

def preview-svg [] {
  with-cache --img --ext png --nostdout {|cache_path|
    if (exists-command rsvg-convert) {
      rsvg-convert $env.filepath -o $cache_path
    } else if (exists-command convert) {
      magick $env.filepath $cache_path
    }
  }
  exiftool -ImageSize -* $env.filepath | bat -l yaml | print -r
}

def preview-epub [] {
  with-cache --img {
    lsar $env.filepath 
    | lines 
    | find -r 'cover.*\.jpe?g'
    | do {
      let cover = $in.0?
      if $cover != null {^unzip -p -j $env.filepath $cover} else {""}
    }
  }
  exiftool --File* $env.filepath | bat -l yaml | print
}

def preview-plist [] {
  if ("/usr/libexec/PlistBuddy" | path exists) {
    /usr/libexec/PlistBuddy -c print Info.plist | bat -l nix | print
  } else {
    bat | print
  }
}

def get-mac-app-info-from-plist [plistpath: string] {
  /usr/libexec/PlistBuddy -c Print $plistpath
  | lines
  | find -r "CFBundleIdentifier|CFBundleDisplayName|CFBundleName|CFBundleShortVersionString" 
  | str replace -r '^ *' '' 
  | str join "\n"
  | bat -l ini
}

def get-mac-app-icon-path-from-plist [plistpath: string] {
  /usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" $plistpath
  | (glob $"($plistpath | path dirname)/Resources/**/($in)*").0?
  | if $in != null {
    let icon_path = $in
    let tmp = (mktemp -t XXX.png)
    sips -s format png $icon_path --out $tmp | ignore
    $tmp
  } else {
    ""
  }
}

def preview-icns [] {
  with-cache --img --ext png --nostdout {|cache_path|
    sips -s format png $env.filepath --out $cache_path
  }
  exiftool -ImageSize -* $env.filepath | bat -l yaml | print
}

def process-compress-file [filepath: string] {
  if (exists-command bsdtar) {
    bsdtar --list --file $filepath
  } else if (exists-command lsar) {
    lsar $filepath | skip 2
  } | tree -C --fromfile .
}

def preview-ipa [] {
  with-cache --img --ext png --nostdout {|cache_path|
    unzip -q -l $env.filepath
    | parse -r '(Payload/.*\.app/AppIcon.*\.png)'
    | do {
      let app_icon_path = $in.0?.capture0?
      if $app_icon_path != null and $app_icon_path != "" {
        let tmp = (mktemp -t)
        unzip -p -j $env.filepath $app_icon_path | save -r -f $tmp
        sips -s format png $tmp --out $cache_path | ignore
        rm $tmp
      }
    }
  }
  with-cache {
    unzip -q -l $env.filepath
    | parse -r '(Payload/.*\.app/Info.plist)'
    | do {
      let info_plist_path = $in.0?.capture0?
      if $info_plist_path != null and $info_plist_path != "" {
        let tmp = (mktemp -t)
        unzip -p -j $env.filepath $info_plist_path | save -r -f $tmp
        let info = (get-mac-app-info-from-plist $tmp)
        rm $tmp
        $info
      } else {
        process-compress-file $env.filepath
      }
    }
  }
}

def preview-dmg [] {
  if not (cache-path | path exists) {
    let dmg_info = (get-dmg-info $env.filepath)
    if $dmg_info != null {
      $dmg_info | get -i mac_icon_path | default "" | if ($in | path exists) {
        let mac_app_path = $in
        with-cache --img --ext png {
          open -r $mac_app_path
        }
      }
      $dmg_info | get -i mac_app_info | default "" | do {
        let mac_app_info = $in
        with-cache {
          $mac_app_info
        }
      }
    }
  } else {
    with-cache --img --ext png --nostdout {}
    with-cache --nostdout {}
  }
}

def get-dmg-info [filepath: string] {
  let mount_path = (
    hdiutil attach $filepath 
    | parse -r '(/Volumes/.*)' 
    | get --ignore-errors 0?.capture0?
  )
  if $mount_path == null {
    # hdiutil info
    return {
      mac_app_info: (hdiutil info)
    }
  }
  mut mac_app_info = ""
  mut mac_icon_path = ""
  let info_plist = (glob $"($mount_path)/*.app/Contents/Info.plist").0?
  if ($info_plist != null) {
    $mac_app_info = (get-mac-app-info-from-plist $info_plist)
    $mac_icon_path = (get-mac-app-icon-path-from-plist $info_plist)
  } else {
    $mac_app_info = (
      tree -C -L 2 $mount_path
    )
  }
  hdiutil detach $mount_path | ignore
  return {
    mac_app_info: $mac_app_info
    mac_icon_path: $mac_icon_path
  }
}

def generate-png-for-ttf-file [
  --font: string
  --dest: string
] {
  let charset = "abcdefghijklmnopqrstuvwxyz\nABCDEFGHIJKLMNOPQRSTUVWXYZ\n1234567890\n!@#$\\%^&*()-_=+[{]}\n\\\\|;:'\",<.>/?`~"
  magick -font $font -background black -fill white -pointsize 50 $"label:($charset)" $dest | ignore
}

def preview-font [] {
  with-cache --img --ext png --nostdout {|cache_path|
    generate-png-for-ttf-file --font $env.filepath --dest $cache_path
  }
  exiftool $env.filepath | bat -l yaml | print
}

def preview-woff [] {
  with-cache --img --ext png --nostdout {|cache_path|
    let tmp_otf = (mktemp -t XXX.otf)
    run-external $"($env.FILE_PWD)/woff2otf.py" $env.filepath $tmp_otf | ignore
    generate-png-for-ttf-file --font $tmp_otf --dest $cache_path
    rm $tmp_otf
  }
}

def preview-woff2 [] {
  with-cache --img --ext png --nostdout {|cache_path|
    let tmp_dir = (mktemp -d)
    let tmp_woff2 = $"($tmp_dir)/a.woff2"
    let tmp_ttf = $"($tmp_dir)/a.ttf"
    cp $env.filepath $tmp_woff2
    woff2_decompress $tmp_woff2
    generate-png-for-ttf-file --font $tmp_ttf --dest $cache_path
    rm -rf $tmp_dir
  }
}

def preview-raf [] {
  with-cache --img {
    ^exiftool $env.filepath --previewimage -b
  }
  show-photo-exiftool $env.filepath | print
}

def preview-compress [] {
  with-cache {
    process-compress-file $env.filepath
  }
}

def preview-video [] {
  if ($env.preview_offset > 9) or ($env.preview_offset < 0) {
    exit 3
  }
  with-cache --ext $env.preview_offset --img --nostdout {|cache_path|
    ffmpegthumbnailer -q 6 -c jpeg -i $env.filepath -o $cache_path -t ($env.preview_offset * 10) -s 600 | ignore
  }
  $env.preview_offset | print
  if (exists-command ffprobe) {
    (ffprobe 
      -select_streams v:0 
      -show_entries format=duration,bit_rate:stream=codec_name,width,height,avg_frame_rate,r_frame_rate,display_aspect_ratio,duration:format_tags 
      -sexagesimal -v quiet -of flat $env.filepath ) 
    | bat -l ini 
    | print -r
  } else {
    exiftool '-AvgBitrate' '-ImageSize' '-Video*' '-Media*' '-Audio*' | bat -l yaml | print
  }
}

def preview-exe-deps [] {
  if (exists-command otool) {
    otool -L $env.filepath
  } else if (exists-command ldd) {
    ldd $env.filepath
  } else {
    file $env.filepath
  }
}
