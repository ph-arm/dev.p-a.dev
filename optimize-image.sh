#!/usr/bin/env bash
#
# optimize-image.sh — turn source photos into responsive, web-optimized assets.
#
# Reads originals from  source-images/  (git-ignored; originals are never
# modified or deleted) and writes, to assets/images/, for every width:
#   <slug>-<w>.avif        primary   (AV1)
#   <slug>-<w>.webp        fallback  (max-effort encode)
#   <slug>-<FALLBACK>.jpg  universal final fallback
# EXIF/GPS/XMP metadata is PRESERVED (JPEG intermediates + copy flags).
#
# Usage:
#   ./optimize-image.sh            process every image in source-images/
#   ./optimize-image.sh <file>     process one file (a path, or a name in
#                                  source-images/, e.g. beach-sunset.jpg)
#
# The output base name (slug) comes from each input's filename, e.g.
#   source-images/beach-sunset.jpg -> beach-sunset-800.avif … beach-sunset-1200.jpg
#
# Requires: sips (macOS), avifenc, cwebp, jpegtran (mozjpeg).

set -euo pipefail

# --- tunables ---------------------------------------------------------------
WIDTHS=(800 1200 1800 2400)   # responsive widths to emit (larger-than-source skipped)
FALLBACK_WIDTH=1200           # width of the universal .jpg fallback
AVIF_Q=62                     # avifenc quality 0..100
AVIF_SPEED=4                  # avifenc speed 0..10 (lower = slower, better)
WEBP_Q=82                     # cwebp quality 0..100
JPEG_Q=80                     # fallback .jpg quality
MID_Q=92                      # quality of the JPEG intermediate feeding avif/webp
# ---------------------------------------------------------------------------

here="$(cd "$(dirname "$0")" && pwd)"
srcdir="$here/source-images"
outdir="$here/assets/images"
mkdir -p "$srcdir" "$outdir"

# Resolve inputs: one argument = that single file; no argument = the whole dir.
inputs=()
if [ "${1:-}" != "" ]; then
  if   [ -f "$1" ];         then inputs=("$1")
  elif [ -f "$srcdir/$1" ]; then inputs=("$srcdir/$1")
  else echo "error: no such file: $1 (also tried $srcdir/$1)" >&2; exit 1; fi
else
  shopt -s nullglob nocaseglob
  inputs=("$srcdir"/*.jpg "$srcdir"/*.jpeg "$srcdir"/*.png \
          "$srcdir"/*.heic "$srcdir"/*.heif "$srcdir"/*.tif "$srcdir"/*.tiff)
  shopt -u nullglob nocaseglob
  if [ "${#inputs[@]}" -eq 0 ]; then
    echo "No images in source-images/. Drop originals there, or pass one file as an argument." >&2
    exit 1
  fi
fi

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

process() {
  local src="$1" base slug sw mid fb w
  base="$(basename "${src%.*}")"
  slug="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | tr ' _' '--' | tr -cd 'a-z0-9-')"
  [ -n "$slug" ] || { echo "skip (empty slug): $src" >&2; return; }

  sw="$(sips -g pixelWidth "$src" | awk '/pixelWidth:/{print $2}')"
  echo "• $(basename "$src")  ->  ${slug}-*   (source ${sw}px wide)"

  for w in "${WIDTHS[@]}"; do
    if [ "$w" -gt "$sw" ]; then
      echo "    ${w}w   skipped (would upscale)"
      continue
    fi
    # High-quality JPEG intermediate; sips carries EXIF/GPS through the resize.
    mid="$tmp/${slug}-${w}.jpg"
    sips -s format jpeg -s formatOptions "$MID_Q" --resampleWidth "$w" "$src" --out "$mid" >/dev/null
    # AVIF — metadata copied from the JPEG input (no --ignore-* flags).
    avifenc -q "$AVIF_Q" -s "$AVIF_SPEED" "$mid" "$outdir/${slug}-${w}.avif" >/dev/null
    # WebP — max effort: method 6, 10 analysis passes, sharper chroma, keep metadata.
    cwebp -q "$WEBP_Q" -m 6 -pass 10 -sharp_yuv -mt -metadata all \
          "$mid" -o "$outdir/${slug}-${w}.webp" >/dev/null 2>&1
    echo "    ${w}w   avif + webp"
  done

  # Universal JPEG fallback (jpegtran -copy all keeps EXIF; lossless repack).
  if [ "$FALLBACK_WIDTH" -le "$sw" ]; then
    fb="$tmp/${slug}-fb.jpg"
    sips -s format jpeg -s formatOptions "$JPEG_Q" --resampleWidth "$FALLBACK_WIDTH" "$src" --out "$fb" >/dev/null
    jpegtran -copy all -optimize -progressive -outfile "$outdir/${slug}-${FALLBACK_WIDTH}.jpg" "$fb"
    echo "    ${FALLBACK_WIDTH}w   jpg (fallback)"
  fi

  echo "    files:"
  ( cd "$outdir" && ls -lh "${slug}"-*.avif "${slug}"-*.webp "${slug}"-*.jpg 2>/dev/null \
      | awk '{printf "      %-28s %s\n", $9, $5}' ) || true
}

for f in "${inputs[@]}"; do
  process "$f"
done

cat <<'EOF'

Done. Reference an image in a post with a responsive <picture> (swap the slug):

  <picture>
    <source type="image/avif" sizes="100vw"
            srcset="/assets/images/SLUG-800.avif 800w, /assets/images/SLUG-1200.avif 1200w,
                    /assets/images/SLUG-1800.avif 1800w, /assets/images/SLUG-2400.avif 2400w">
    <source type="image/webp" sizes="100vw"
            srcset="/assets/images/SLUG-800.webp 800w, /assets/images/SLUG-1200.webp 1200w,
                    /assets/images/SLUG-1800.webp 1800w, /assets/images/SLUG-2400.webp 2400w">
    <img src="/assets/images/SLUG-1200.jpg" alt="DESCRIBE THE IMAGE" loading="lazy" decoding="async">
  </picture>
EOF
