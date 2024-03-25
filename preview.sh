#!/bin/bash
# shellcheck disable=2034

set -o noclobber -o noglob -o nounset -o pipefail
IFS=$'\n'

FILE_PATH=""
FILE_SIZE=0
PREVIEW_WIDTH=50
PREVIEW_HEIGHT=50
PREVIEW_OFFSET=0

while [ "$#" -gt 0 ]; do
  case "$1" in
  "--path")
    shift
    FILE_PATH="$1"
    ;;
  "--width")
    shift
    PREVIEW_WIDTH="$1"
    ;;
  "--height")
    shift
    PREVIEW_HEIGHT="$1"
    ;;
  "--offset")
    shift
    PREVIEW_OFFSET="$1"
    ;;
  esac
  shift
done

FILE_EXTENSION="${FILE_PATH##*.}"
FILE_EXTENSION_LOWER="$(printf "%s" "${FILE_EXTENSION}" | tr '[:upper:]' '[:lower:]')"
FILE_NAME="${FILE_PATH##*/}"

bat() {
  command bat "$@" \
    --color=always --paging=never \
    --style=plain \
    --wrap=character \
    --line-range :5000 \
    --terminal-width="${PREVIEW_WIDTH}"
}

die() {
  if [ -e /dev/stderr ]; then
    printf "\033[1;31m%s\033[m\n\r" "$*" >>/dev/stderr
  elif [ -e /dev/fd/2 ]; then
    printf "\033[1;31m%s\033[m\n\r" "$*" >>/dev/fd/2
  else
    printf "\033[1;31m%s\033[m\n\r" "$*"
  fi
  exit 255
}

exiftool() {
  command exiftool '--ExifTool*' '--Directory' '--File*' '--ProfileDescription*' "$@"
}

handle_text() {
  bat "${FILE_PATH}" && exit
}

handle_json() {
  bat -l json "$FILE_PATH" --theme=TwoDark && exit
  # jq -C --tab . "${FILE_PATH}" && exit
  # handle_text
}

echo_image_path() {
  echo "__preview__image__path__ $1"
  echo -e "\033[1;30m─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────\033[0m"
}

with_cache() {
  local cache=""
  local ext=""
  local echo_image=false
  local cat_cache=false
  local no_stdout=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
    "-ext")
      shift
      ext=".$1"
      ;;
    "-cat")
      cat_cache=true
      ;;
    "-img")
      echo_image=true
      ;;
    "--no-stdout")
      no_stdout=true
      ;;
    "--")
      shift
      break
      ;;
    esac
    shift
  done

  cache="${TMPDIR:-/tmp/}yazi/$(ls -l "$FILE_PATH" | md5sum | cut -d ' ' -f 1)${ext}"
  if [ ! -f "$cache" ]; then
    if "$no_stdout"; then
      "$@" &>/dev/null
    else
      "$@" >"$cache" 2>/dev/null
    fi
  fi
  if "$echo_image"; then
    echo_image_path "$cache"
  fi
  if "$cat_cache" && [ -f "$cache" ]; then
    cat "$cache"
  fi
}

handle_audio() {
  with_cache -img -- exiftool -b -CoverArt -Picture "$FILE_PATH"
  exiftool -Title -SortName -TitleSort -TitleSortOrder -Artist -SortArtist -ArtistSort -PerformerSortOrder \
    -Album -SortAlbum -AlbumSort -AlbumSortOrder -AlbumArtist -SortAlbumArtist -AlbumArtistSort -AlbumArtistSortOrder \
    -Genre -TrackNumber -Year -Duration -SampleRate -AudioSampleRate -AudioBitrate -AvgBitrate -Channels -AudioChannels "$FILE_PATH" | bat -l yaml
  # ffprobe -select_streams a:0 \
  #   -show_entries format=duration,bit_rate:stream=codec_name,sample_rate,channels,bits_per_raw_sample:format_tags \
  #   -sexagesimal -v quiet -of flat "${FILE_PATH}" | bat -l ini
  exit
}

handle_video() {
  # mediainfo "${FILE_PATH}" && exit 5
  #   exiftool "${FILE_PATH}" && exit 5
  if [ "$PREVIEW_OFFSET" -gt 9 ] || [ "$PREVIEW_OFFSET" -lt 0 ]; then
    exit 3
  fi
  with_cache -ext "$PREVIEW_OFFSET" -img -- ffmpegthumbnailer -q 6 -c jpeg -i "$FILE_PATH" -o /dev/stdout -t $((PREVIEW_OFFSET * 10)) -s 600
  echo "$PREVIEW_OFFSET"
  ffprobe -select_streams v:0 \
    -show_entries format=duration,bit_rate:stream=codec_name,width,height,avg_frame_rate,r_frame_rate,display_aspect_ratio,duration:format_tags \
    -sexagesimal -v quiet -of flat "${FILE_PATH}" | bat -l ini
  exit
}

process_compress_file() {
  (bsdtar --list --file "${FILE_PATH}" || (lsar "${FILE_PATH}" | tail -n +2)) | tree -C --fromfile .
  # bsdtar --list --file "${FILE_PATH}" | tree -C --fromfile .
}

handle_compress() {
  with_cache -cat -- process_compress_file
  exit
}

handle_bin() {
  nm "$FILE_PATH" && exit
  nm -D "$FILE_PATH" && exit

  exit
}

process_pdf() {
  pdftoppm -singlefile -jpeg -jpegopt quality=75 -f $((PREVIEW_OFFSET + 1)) "$FILE_PATH"
  if [ "$?" -eq 99 ]; then
    exit 3
  fi
}

handle_pdf() {
  with_cache -ext "$PREVIEW_OFFSET" -img -- process_pdf
  echo "$PREVIEW_OFFSET"
  pdfinfo "$FILE_PATH" | bat -l yaml
  exit
}

process_ipynb() {
  jupyter-nbconvert "${FILE_PATH}" --to markdown --stdout | glow -s dracula --width "$PREVIEW_WIDTH" -
}

handle_ipynb() {
  with_cache -cat -- process_ipynb
}

handle_svg() {
  with_cache -img -- convert "$FILE_PATH" -write JPG:- -
  exiftool '-ImageSize' '-*' "${FILE_PATH}" | bat -l yaml
  exit
}

handle_image() {
  echo_image_path "$FILE_PATH"
  exiftool '-ImageSize' '-*' "${FILE_PATH}" | bat -l yaml
  exit
}

process_doc() {
  pandoc -s -t markdown -- "$FILE_PATH" | glow -s dracula --width "$PREVIEW_WIDTH" - && return
  textutil -stdout -cat txt "$FILE_PATH"
}

disable_auto_peek() {
  echo "__disable_auto_peek__"
}

preview_sqlite3() {
  # if [ "$PREVIEW_OFFSET" == 0 ]; then
  sqlite3 "$FILE_PATH" .schema | sed "s/;/;\n/g" | bat -l sql
  # else
  #   disable_auto_peek
  #   local table="$(sqlite3 -header "$FILE_PATH" .tables | tr '\n' " " | tr -s " " | cut -d " " -f "$PREVIEW_OFFSET")"
  #   if [ -z "$table" ]; then
  #     exit 3
  #   fi
  #   local sql="SELECT * FROM $table LIMIT 100;"
  #   echo -e "${sql}\n" | bat -l sql
  #   # sqlite3 will append hex d4 to the end of last column name, which will crash preview, so remove it
  #   sqlite3 -header -csv "$FILE_PATH" "$sql" | sed 's/\xd4//g' | mlr --icsv --opprint -C --key-color darkcyan --value-color grey70 cat
  # fi
}

process_netease_uc() {
  nc2mp3 --info "$FILE_PATH" | bat -l json --theme TwoDark
}

process_epub() {
  local cover="$(lsar "$FILE_PATH" | grep -E 'cover.*\.jpe?g')"
  if [ -z "$cover" ]; then
    return
  fi
  unzip -p -j "$FILE_PATH" "$cover"
}

process_baksmali() {
  baksmali list class "${FILE_PATH}" | tree -C --fromfile .
}

process_xlsx() {
  xlsx2csv -- "$FILE_PATH" | head -n 500 | mlr --icsv --opprint -C --key-color darkcyan --value-color grey70 cat
}

process_xls() {
  xls2csv -- "$FILE_PATH" | head -n 500 | mlr --icsv --opprint -C --key-color darkcyan --value-color grey70 cat
}

call_aapt() {
  if command -v aapt &>/dev/null; then
    command aapt "$@"
    return
  else
    local sdk_path="${HOME}/Library/Android/sdk/build-tools"
    if [ -d "$sdk_path" ]; then
      local ver="$(ls "$sdk_path" | head -n 1)"
      local aapt_path="${sdk_path}/${ver}/aapt2"
      if [ -f "$aapt_path" ]; then
        "$aapt_path" "$@"
        return
      fi
    fi
  fi
  command aapt "$@"
}

handle_extension() {
  case "${FILE_EXTENSION_LOWER}" in
  # rar)
  #   ## Avoid password prompt by providing empty password
  #   unrar lt -p- -- "${FILE_PATH}" && exit
  #   exit
  #   ;;
  # 7z)
  #   ## Avoid password prompt by providing empty password
  #   7z l -p -- "${FILE_PATH}" && exit
  #   exit
  #   ;;
  mp3 | flac | wav | m4a)
    handle_audio
    ;;
  json)
    handle_json
    ;;
  pdf)
    handle_pdf
    ;;
  toml | tmpl | xml | arsc)
    handle_text
    ;;
  md)
    glow -s dracula --width "$PREVIEW_WIDTH" "$FILE_PATH"
    ;;
  ipynb)
    handle_ipynb && exit
    handle_text
    ;;
  dex)
    with_cache -cat -- process_baksmali
    ;;
  apk)
    call_aapt dump badging "${FILE_PATH}" && exit
    handle_compress
    ;;
  csv | tsv)
    mlr --icsv --opprint -C --key-color darkcyan --value-color grey70 head -n 500 "${FILE_PATH}"
    ;;
  uc!)
    with_cache -cat -- process_netease_uc
    ;;
  sqlite3 | sqlite)
    preview_sqlite3
    ;;
  so | dylib)
    handle_bin
    ;;
  dmg)
    hdiutil imageinfo "$FILE_PATH" | bat -l yaml
    ;;
  torrent)
    transmission-show -- "$FILE_PATH"
    ;;
  doc | docx | htm | html | xhtml)
    with_cache -cat -- process_doc
    ;;
  xlsx)
    with_cache -cat -- process_xlsx
    ;;
  xls)
    with_cache -cat -- process_xls
    ;;
  svg)
    handle_svg
    ;;
  epub)
    with_cache -img -- process_epub
    exiftool '--File*' "$FILE_PATH" | bat -l yaml
    ;;
  ## Archive
  7z | rar | ace | alz | arc | arj | bz | bz2 | cab | cpio | deb | gz | jar | lha | lz | lzh | lzma | lzo | \
    rpm | rz | t7z | tar | tbz | tbz2 | tgz | tlz | txz | tZ | tzo | war | xpi | xz | Z | zip | nds | ipa | iso | pkg)
    handle_compress
    ;;
  *)
    return
    ;;
  esac
  exit
}

handle_mime() {
  local mimetype="${1}"

  case "${mimetype}" in
  *archive | *zip)
    handle_compress
    ;;
  # application/zip)
  #   unzip -l "$FILE_PATH"
  #   exit
  #   ;;
  text/* | */xml | */javascript)
    handle_text
    ;;
  */json)
    handle_json
    ;;
  image/*)
    handle_image
    ;;
  video/*)
    handle_video
    ;;
  audio/*)
    handle_audio
    ;;
  */pdf)
    handle_pdf
    ;;
  */x-sharedlib | */x-object | */x-mach-binary | *executable)
    handle_bin
    ;;
  *sqlite3)
    preview_sqlite3
    ;;
  *)
    return
    ;;
  esac
  exit
}

if ! [[ -f "$FILE_PATH" ]]; then
  die "<No such file>"
fi

if ! [[ -r "$FILE_PATH" ]]; then
  die "<Permission denied>"
fi

handle_extension
handle_mime "$(file -bL --mime-type -- "${FILE_PATH}")"

# fallback to display raw text
head -c 100000 "$FILE_PATH" | LC_CTYPE=C LANG=C sed 's/[^[:print:]]//g' | fold -w "$PREVIEW_WIDTH"
