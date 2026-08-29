#!/bin/sh

set -eu

fail()
{
    echo "package: $*" >&2
    exit 1
}

require_command()
{
    command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

require_file()
{
    [ -f "$1" ] || fail "required file is missing: $1"
}

verify_revision()
{
    component_name=$1
    component_dir=$2
    expected_revision=$3

    require_file "$component_dir/.git"
    actual_revision=$(git -C "$component_dir" rev-parse HEAD) ||
        fail "cannot read the pinned revision for $component_name"
    [ "$actual_revision" = "$expected_revision" ] ||
        fail "$component_name is at $actual_revision, expected $expected_revision"
}

verify_pristine()
{
    component_name=$1
    component_dir=$2

    source_status=$(
        git -C "$component_dir" status --short --untracked-files=all \
            --ignored --ignore-submodules=all
    ) || fail "cannot inspect source cleanliness for $component_name"
    if [ -n "$source_status" ]; then
        echo "package: $component_name source tree is not pristine: $component_dir" >&2
        printf '%s\n' "$source_status" >&2
        exit 1
    fi
}

copy_license()
{
    source_file=$1
    destination_dir=$2

    require_file "$source_file"
    mkdir -p "$destination_dir"
    cp "$source_file" "$destination_dir/"
}

for required_command in \
    awk \
    cat \
    chmod \
    cmp \
    cp \
    cut \
    dirname \
    find \
    git \
    grep \
    gzip \
    ldd \
    mkdir \
    mv \
    readelf \
    rm \
    sed \
    sha256sum \
    sort \
    tar \
    uname
do
    require_command "$required_command"
done

[ "$(uname -s)" = "Linux" ] || fail "packaging currently supports Linux only"
[ "$(uname -m)" = "x86_64" ] || fail "packaging currently supports x86-64 only"

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
build_dir_setting=${BUILD_DIR:-build}

case "$build_dir_setting" in
    /*) build_dir=$build_dir_setting ;;
    *) build_dir=$repo_root/$build_dir_setting ;;
esac

[ -d "$build_dir" ] || fail "build directory is missing: $build_dir"
build_dir=$(CDPATH= cd -- "$build_dir" && pwd -P)
case "$build_dir/" in
    "$repo_root"/*/) ;;
    *) fail "BUILD_DIR must be inside the repository: $build_dir" ;;
esac

rapidgzip_binary=$build_dir/rapidgzip
require_file "$rapidgzip_binary"
[ -x "$rapidgzip_binary" ] || fail "production executable is not executable: $rapidgzip_binary"

version_output=$("$rapidgzip_binary" --version) ||
    fail "production executable did not report its version"
upstream_version=$(
    printf '%s\n' "$version_output" |
        sed -n 's/^.* rapidgzip version \([0-9][0-9A-Za-z.]*\)$/\1/p'
)
[ -n "$upstream_version" ] ||
    fail "could not derive the upstream version from: $version_output"

distribution_version=${DIST_VERSION:-$upstream_version}
case "$distribution_version" in
    ''|*[!0-9A-Za-z.+_-]*)
        fail "invalid distribution version: $distribution_version"
        ;;
esac
case "$distribution_version" in
    "$upstream_version"|"$upstream_version"-*|"$upstream_version"+*) ;;
    *)
        fail "distribution version must be $upstream_version or a -/+ suffixed variant"
        ;;
esac

rapidgzip_root=$repo_root/external/rapidgzip
librapidarchive_root=$rapidgzip_root/librapidarchive
cxxopts_root=$librapidarchive_root/src/external/cxxopts
isal_root=$librapidarchive_root/src/external/isa-l
rpmalloc_root=$librapidarchive_root/src/external/rpmalloc
zlib_ng_root=$librapidarchive_root/src/external/zlib-ng

rapidgzip_revision=d2350e9c9ba54398cd64e45bfc8c631beec017f0
librapidarchive_revision=1221a30bb548b305a69e5715f2bc348ba37ac243
cxxopts_revision=44380e5a44706ab7347f400698c703eb2a196202
isal_revision=6a7c87e34293f427600e37f702d8a4d73391e48d
rpmalloc_revision=66fd705a811764035ec80f54928748d2b31a3827
zlib_ng_revision=860e4cff7917d93f54f5d7f0bc1d0e8b1a3cb988

# These guards intentionally force a packaging/license review when any pinned
# implementation component changes.
verify_revision rapidgzip "$rapidgzip_root" "$rapidgzip_revision"
verify_revision librapidarchive "$librapidarchive_root" "$librapidarchive_revision"
verify_revision cxxopts "$cxxopts_root" "$cxxopts_revision"
verify_revision ISA-L "$isal_root" "$isal_revision"
verify_revision rpmalloc "$rpmalloc_root" "$rpmalloc_revision"
verify_revision zlib-ng "$zlib_ng_root" "$zlib_ng_revision"
verify_pristine rapidgzip "$rapidgzip_root"
verify_pristine librapidarchive "$librapidarchive_root"
verify_pristine cxxopts "$cxxopts_root"
verify_pristine ISA-L "$isal_root"
verify_pristine rpmalloc "$rpmalloc_root"
verify_pristine zlib-ng "$zlib_ng_root"

require_file "$repo_root/README.md"
require_file "$repo_root/LICENSE"

dist_dir=$repo_root/dist
package_name=rapidgzip-unpythoned-$distribution_version-linux-x86_64
archive_name=$package_name.tar.gz
checksum_name=$archive_name.sha256
staging_root=$dist_dir/.package-staging
package_dir=$staging_root/$package_name
self_test_root=$dist_dir/.package-self-test.$$
temporary_archive=$dist_dir/.$archive_name.tmp.$$
manifest_file=$dist_dir/.package-manifest.$$
archive_path=$dist_dir/$archive_name
checksum_path=$dist_dir/$checksum_name

cleanup()
{
    rm -rf "$staging_root" "$self_test_root"
    rm -f "$temporary_archive" "$manifest_file"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$dist_dir"
rm -rf "$staging_root" "$self_test_root"
rm -f "$temporary_archive" "$manifest_file" "$archive_path" "$checksum_path"
mkdir -p "$package_dir/licenses"

cp "$rapidgzip_binary" "$package_dir/rapidgzip"
cp "$repo_root/README.md" "$package_dir/README.md"
cp "$repo_root/LICENSE" "$package_dir/LICENSE"

copy_license "$rapidgzip_root/LICENSE-APACHE" "$package_dir/licenses/rapidgzip"
copy_license "$rapidgzip_root/LICENSE-MIT" "$package_dir/licenses/rapidgzip"
copy_license "$librapidarchive_root/LICENSE-APACHE" "$package_dir/licenses/librapidarchive"
copy_license "$librapidarchive_root/LICENSE-MIT" "$package_dir/licenses/librapidarchive"
copy_license "$cxxopts_root/LICENSE" "$package_dir/licenses/cxxopts"
copy_license "$isal_root/LICENSE" "$package_dir/licenses/isa-l"
copy_license "$rpmalloc_root/LICENSE" "$package_dir/licenses/rpmalloc"
copy_license "$rpmalloc_root/UNLICENSE" "$package_dir/licenses/rpmalloc"
copy_license "$zlib_ng_root/LICENSE.md" "$package_dir/licenses/zlib-ng"

"$package_dir/rapidgzip" --oss-attributions-yaml > "$package_dir/OSS_ATTRIBUTIONS.yaml"
[ -s "$package_dir/OSS_ATTRIBUTIONS.yaml" ] ||
    fail "rapidgzip produced empty OSS attribution data"
grep -Fq 'root_name: rapidgzip' "$package_dir/OSS_ATTRIBUTIONS.yaml" ||
    fail "rapidgzip produced unexpected OSS attribution data"

cat > "$package_dir/THIRD_PARTY_NOTICES.md" <<EOF
# Upstream and third-party notices

This distribution contains the unchanged rapidgzip CLI implementation and the
pinned implementation dependencies listed below. Complete license texts are at
the indicated paths. OSS_ATTRIBUTIONS.yaml is the verbatim output of this
binary's --oss-attributions-yaml option.

## Upstream rapidgzip implementation

### rapidgzip

- Upstream version reported by the binary: $upstream_version
- Pinned source revision: $rapidgzip_revision
- License metadata: the pinned CITATION.cff reports MIT; the upstream tree
  ships both MIT and Apache-2.0 license texts.
- License files: licenses/rapidgzip/LICENSE-MIT,
  licenses/rapidgzip/LICENSE-APACHE

### librapidarchive

- Pinned source revision: $librapidarchive_revision
- Upstream does not assign this pinned library tree a separate version.
- License: Apache-2.0 OR MIT
- License files: licenses/librapidarchive/LICENSE-APACHE,
  licenses/librapidarchive/LICENSE-MIT

## Third-party implementation dependencies

### cxxopts

- Version in the pinned header: 3.3.1
- Pinned source revision: $cxxopts_revision
- License in the pinned source: MIT
- License file: licenses/cxxopts/LICENSE
- Attribution distinction: the embedded YAML labels this license "Unlicense",
  but its embedded text is the MIT text and matches the pinned MIT license file.

### ISA-L

- Pinned source revision: $isal_revision
- Version metadata differs within the pinned inputs: CMake reports 2.31.0 and
  configure.ac reports 2.31.1. The embedded YAML reports 2.30.0.
- License: BSD-3-Clause (called BSD-3 by the embedded YAML)
- License file: licenses/isa-l/LICENSE

### rpmalloc

- Pinned source revision: $rpmalloc_revision
- The pinned changelog begins with 1.4.5; the embedded YAML reports 1.4.4.
- Licenses in the pinned source: 0BSD and Unlicense
- License files: licenses/rpmalloc/LICENSE,
  licenses/rpmalloc/UNLICENSE
- Attribution distinction: rapidgzip's embedded YAML retains older
  Unlicense/MIT attribution text. The adjacent YAML preserves that upstream
  output, while the complete current license files above come from the exact
  pinned rpmalloc checkout.

### zlib-ng compatibility implementation

- Version in the pinned zlib-ng header: 2.2.4
- Pinned source revision: $zlib_ng_revision
- License: zlib License
- License file: licenses/zlib-ng/LICENSE.md
- Attribution distinction: the embedded YAML identifies the compatibility API
  as "zlib" 1.3.1. The linked implementation is the pinned zlib-ng source, not
  the separately pinned classic-zlib submodule.
EOF

find "$package_dir" -type d -exec chmod 0755 {} +
find "$package_dir" -type f -exec chmod 0644 {} +
chmod 0755 "$package_dir/rapidgzip"

(
    CDPATH= cd -- "$staging_root"
    find "$package_name" -printf '%P\t%y\n' | LC_ALL=C sort
) > "$manifest_file"

source_date_epoch=${SOURCE_DATE_EPOCH:-0}
case "$source_date_epoch" in
    ''|*[!0-9]*) fail "SOURCE_DATE_EPOCH must be a non-negative integer" ;;
esac

LC_ALL=C tar \
    --sort=name \
    --format=gnu \
    --mtime="@$source_date_epoch" \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    -czf "$temporary_archive" \
    -C "$staging_root" \
    "$package_name"

mkdir -p "$self_test_root"
archive_top_levels=$(
    tar -tzf "$temporary_archive" |
        sed 's#^\./##' |
        cut -d/ -f1 |
        LC_ALL=C sort -u
)
[ "$archive_top_levels" = "$package_name" ] ||
    fail "archive does not contain exactly the expected top-level directory"

tar -xzf "$temporary_archive" -C "$self_test_root"
extracted_dir=$self_test_root/$package_name
(
    CDPATH= cd -- "$extracted_dir"
    find . -printf '%P\t%y\n' | LC_ALL=C sort
) > "$self_test_root/extracted-manifest"
cmp "$manifest_file" "$self_test_root/extracted-manifest" ||
    fail "archive contents differ from the staged package"

for required_package_file in \
    rapidgzip \
    README.md \
    LICENSE \
    OSS_ATTRIBUTIONS.yaml \
    THIRD_PARTY_NOTICES.md
do
    require_file "$extracted_dir/$required_package_file"
done
for required_license_dir in \
    rapidgzip \
    librapidarchive \
    cxxopts \
    isa-l \
    rpmalloc \
    zlib-ng
do
    [ -d "$extracted_dir/licenses/$required_license_dir" ] ||
        fail "required license directory is missing: licenses/$required_license_dir"
done

cmp "$repo_root/README.md" "$extracted_dir/README.md"
cmp "$repo_root/LICENSE" "$extracted_dir/LICENSE"
cmp "$rapidgzip_root/LICENSE-APACHE" \
    "$extracted_dir/licenses/rapidgzip/LICENSE-APACHE"
cmp "$rapidgzip_root/LICENSE-MIT" \
    "$extracted_dir/licenses/rapidgzip/LICENSE-MIT"
cmp "$librapidarchive_root/LICENSE-APACHE" \
    "$extracted_dir/licenses/librapidarchive/LICENSE-APACHE"
cmp "$librapidarchive_root/LICENSE-MIT" \
    "$extracted_dir/licenses/librapidarchive/LICENSE-MIT"
cmp "$cxxopts_root/LICENSE" "$extracted_dir/licenses/cxxopts/LICENSE"
cmp "$isal_root/LICENSE" "$extracted_dir/licenses/isa-l/LICENSE"
cmp "$rpmalloc_root/LICENSE" "$extracted_dir/licenses/rpmalloc/LICENSE"
cmp "$rpmalloc_root/UNLICENSE" "$extracted_dir/licenses/rpmalloc/UNLICENSE"
cmp "$zlib_ng_root/LICENSE.md" "$extracted_dir/licenses/zlib-ng/LICENSE.md"

cmp "$rapidgzip_binary" "$extracted_dir/rapidgzip" ||
    fail "packaged executable differs from build/rapidgzip"
"$extracted_dir/rapidgzip" --version > "$self_test_root/version.txt"
grep -Fq "rapidgzip version $upstream_version" "$self_test_root/version.txt" ||
    fail "packaged executable reports an unexpected version"
"$extracted_dir/rapidgzip" --help > "$self_test_root/help.txt"
grep -Fq -- '--oss-attributions-yaml' "$self_test_root/help.txt" ||
    fail "packaged executable help is unexpected"
"$extracted_dir/rapidgzip" --oss-attributions-yaml > "$self_test_root/attributions.yaml"
cmp "$extracted_dir/OSS_ATTRIBUTIONS.yaml" "$self_test_root/attributions.yaml" ||
    fail "packaged attribution output does not match OSS_ATTRIBUTIONS.yaml"

printf '%s\n' 'rapidgzip-unpythoned packaged executable smoke test' \
    > "$self_test_root/payload.txt"
gzip -n -c "$self_test_root/payload.txt" > "$self_test_root/payload.txt.gz"
"$extracted_dir/rapidgzip" -d -c "$self_test_root/payload.txt.gz" \
    > "$self_test_root/output.txt"
cmp "$self_test_root/payload.txt" "$self_test_root/output.txt" ||
    fail "packaged executable decompression smoke test failed"

readelf -h "$extracted_dir/rapidgzip" > "$self_test_root/elf-header.txt"
grep -Eq 'Machine:[[:space:]]+Advanced Micro Devices X86-64' \
    "$self_test_root/elf-header.txt" ||
    fail "packaged executable is not an x86-64 ELF binary"
readelf -d "$extracted_dir/rapidgzip" > "$self_test_root/dynamic.txt"
if grep -Eq '\((RPATH|RUNPATH)\)' "$self_test_root/dynamic.txt"; then
    fail "packaged executable contains an RPATH or RUNPATH"
fi
ldd "$extracted_dir/rapidgzip" > "$self_test_root/ldd.txt"
if grep -Fq "$repo_root" "$self_test_root/ldd.txt"; then
    fail "packaged executable has a runtime dependency inside the repository"
fi

mv "$temporary_archive" "$archive_path"
(
    CDPATH= cd -- "$dist_dir"
    sha256sum "$archive_name" > "$checksum_name"
    sha256sum --check "$checksum_name"
)

echo "Created $archive_path"
echo "Created $checksum_path"
