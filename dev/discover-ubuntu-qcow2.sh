#!/usr/bin/env bash
# Discover and download the Ubuntu Minimal QCOW2 corresponding to an
# Ubuntu archive-team cloud-minimal seed URL.
#
# Works on Ubuntu and WSL2. It downloads the current released image by
# default, verifies SHA-256, and checks the image format when qemu-img exists.

set -Eeuo pipefail
IFS=$'\n\t'
LC_ALL=C

DEFAULT_SEED_URL='https://ubuntu-archive-team.ubuntu.com/seeds/ubuntu.noble/cloud-minimal'
SEED_URL="$DEFAULT_SEED_URL"
ARCH=''
OUTPUT=''
CHANNEL='release'
PRINT_ONLY=0
FORCE=0

usage() {
  cat <<'USAGE'
Usage:
  discover-ubuntu-qcow2.sh [options] [seed-url]

Options:
  --arch ARCH       Ubuntu architecture: amd64 or arm64.
                    Default: inferred from uname -m.
  --output PATH     Destination path. Default: discovered-name.qcow2
  --daily           Use the current daily build instead of released build.
  --print-only      Print discovery details without downloading.
  --force           Replace an existing destination file.
  -h, --help        Show this help.

Example:
  ./discover-ubuntu-qcow2.sh
  ./discover-ubuntu-qcow2.sh --arch amd64 --output noble-minimal.qcow2
USAGE
}

log()  { printf '[ubuntu-qcow2] %s\n' "$*" >&2; }
warn() { printf '[ubuntu-qcow2] warning: %s\n' "$*" >&2; }
die()  { printf '[ubuntu-qcow2] error: %s\n' "$*" >&2; exit 1; }

while (($#)); do
  case "$1" in
    --arch)
      (($# >= 2)) || die '--arch requires a value'
      ARCH=$2
      shift 2
      ;;
    --output)
      (($# >= 2)) || die '--output requires a value'
      OUTPUT=$2
      shift 2
      ;;
    --daily)
      CHANNEL='daily'
      shift
      ;;
    --print-only)
      PRINT_ONLY=1
      shift
      ;;
    --force)
      FORCE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      (($# <= 1)) || die 'only one seed URL may be supplied'
      (($# == 0)) || SEED_URL=$1
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      [[ $SEED_URL == "$DEFAULT_SEED_URL" ]] || die 'only one seed URL may be supplied'
      SEED_URL=$1
      shift
      ;;
  esac
done

case "${ARCH:-$(uname -m)}" in
  amd64|x86_64)  ARCH='amd64' ;;
  arm64|aarch64) ARCH='arm64' ;;
  *) die "unsupported architecture: ${ARCH:-$(uname -m)}; use --arch amd64 or --arch arm64" ;;
esac

# Strip query/fragment/trailing slash and extract:
#   .../seeds/ubuntu.noble/cloud-minimal
clean_seed_url=${SEED_URL%%\?*}
clean_seed_url=${clean_seed_url%%\#*}
clean_seed_url=${clean_seed_url%/}
seed_name=${clean_seed_url##*/}
seed_parent=${clean_seed_url%/*}
seed_series_dir=${seed_parent##*/}

[[ $seed_series_dir == ubuntu.* ]] || \
  die "cannot extract Ubuntu series from seed URL: $SEED_URL"
series=${seed_series_dir#ubuntu.}
[[ -n $series ]] || die "empty Ubuntu series in seed URL: $SEED_URL"

case "$seed_name" in
  cloud-minimal) image_family='minimal' ;;
  *) die "unsupported seed '$seed_name'; expected cloud-minimal" ;;
esac

if [[ $CHANNEL == release ]]; then
  image_dir="https://cloud-images.ubuntu.com/${image_family}/releases/${series}/release"
else
  image_dir="https://cloud-images.ubuntu.com/${image_family}/daily/${series}/current"
fi
checksums_url="${image_dir}/SHA256SUMS"

tmpdir=$(mktemp -d)
cleanup() { rm -rf "$tmpdir"; }
trap cleanup EXIT

fetch_to_file() {
  local url=$1 destination=$2
  if command -v curl >/dev/null 2>&1; then
    curl --fail --location --silent --show-error \
      --retry 3 --retry-delay 1 --connect-timeout 20 \
      --output "$destination" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget --quiet --tries=3 --timeout=20 --output-document="$destination" "$url"
  else
    die 'curl or wget is required'
  fi
}

# Validate that the starting point is reachable and looks like the expected seed.
fetch_to_file "$clean_seed_url" "$tmpdir/seed"
if ! grep -Eqi 'Minimal Ubuntu cloud|server-cloud-minimal|ubuntu-cloud-minimal' "$tmpdir/seed"; then
  die "the URL is reachable, but does not look like Ubuntu's cloud-minimal seed"
fi

# SHA256SUMS is the machine-readable discovery surface. It carries both the
# current image filename and its expected digest.
fetch_to_file "$checksums_url" "$tmpdir/SHA256SUMS"

checksum_entry=$(
  awk -v arch="$ARCH" '
    $2 ~ ("minimal-cloudimg-" arch "\\.img$") {
      print $1, $2
      exit
    }
  ' "$tmpdir/SHA256SUMS"
)

[[ -n $checksum_entry ]] || \
  die "no ${series} minimal QCOW2 image for ${ARCH} was found in $checksums_url"
expected_sha=${checksum_entry%% *}
file_field=${checksum_entry#* }

filename=${file_field#\*}
image_url="${image_dir}/${filename}"
[[ -n $OUTPUT ]] || OUTPUT="${filename%.img}.qcow2"

cat <<DETAILS
Seed URL:      $clean_seed_url
Ubuntu series: $series
Seed:          $seed_name
Channel:       $CHANNEL
Architecture:  $ARCH
Image URL:     $image_url
SHA-256:       $expected_sha
Destination:   $OUTPUT
DETAILS

((PRINT_ONLY)) && exit 0

command -v sha256sum >/dev/null 2>&1 || die 'sha256sum is required'
mkdir -p "$(dirname "$OUTPUT")"

if [[ -e $OUTPUT && $FORCE -eq 0 ]]; then
  actual_sha=$(sha256sum "$OUTPUT" | awk '{print $1}')
  if [[ $actual_sha == "$expected_sha" ]]; then
    log "existing image is already current and verified: $OUTPUT"
  else
    die "destination exists with a different checksum: $OUTPUT (use --force to replace it)"
  fi
else
  partial="${OUTPUT}.part"
  rm -f "$partial"
  trap 'rm -f "${partial:-}"; cleanup' EXIT

  log "downloading $image_url"
  fetch_to_file "$image_url" "$partial"

  actual_sha=$(sha256sum "$partial" | awk '{print $1}')
  [[ $actual_sha == "$expected_sha" ]] || \
    die "SHA-256 mismatch: expected $expected_sha, got $actual_sha"

  mv -f "$partial" "$OUTPUT"
  log "SHA-256 verified"
fi

if command -v qemu-img >/dev/null 2>&1; then
  if qemu-img info "$OUTPUT" | grep -q '^file format: qcow2$'; then
    log 'qemu-img confirms QCOW2 format'
    qemu-img info "$OUTPUT"
  else
    die 'downloaded image is not reported as QCOW2 by qemu-img'
  fi
else
  warn 'qemu-img not found; install package qemu-utils for format inspection'
fi

printf '%s  %s\n' "$expected_sha" "$OUTPUT" > "${OUTPUT}.sha256"
printf '%s\n' "$image_url" > "${OUTPUT}.source-url"
log "ready: $OUTPUT"
