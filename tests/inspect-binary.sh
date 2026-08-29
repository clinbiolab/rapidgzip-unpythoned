#!/bin/sh

set -eu

if [ "$#" -ne 6 ]; then
    echo "usage: inspect-binary.sh RAPIDGZIP BUILD_DIR READELF NM GREP AWK" >&2
    exit 2
fi

rapidgzip=$1
build_dir=$2
readelf_command=$3
nm_command=$4
grep_command=$5
awk_command=$6

inspection_dir="$build_dir/test-work/binary-inspection"
mkdir -p "$inspection_dir"

test -f "$build_dir/librpmalloc.a"
test -f "$build_dir/libzlibstatic.a"
test -f "$build_dir/deps/isa-l/libisal.a"

"$readelf_command" -h "$rapidgzip" > "$inspection_dir/elf-header.txt"
"$grep_command" -Eq 'Type:[[:space:]]+DYN' "$inspection_dir/elf-header.txt"

"$readelf_command" -l "$rapidgzip" > "$inspection_dir/program-headers.txt"
"$grep_command" -Fq 'GNU_RELRO' "$inspection_dir/program-headers.txt"

"$readelf_command" -d "$rapidgzip" > "$inspection_dir/dynamic.txt"
"$grep_command" -Eq 'FLAGS(_1)?.*(NOW|BIND_NOW)' "$inspection_dir/dynamic.txt"

for forbidden_dependency in \
    'libz.so' \
    'libisal' \
    'librpmalloc' \
    'libpython' \
    'libstdc++.so' \
    'libgcc_s.so'
do
    if "$grep_command" -Fq "$forbidden_dependency" "$inspection_dir/dynamic.txt"; then
        echo "unexpected dynamic dependency: $forbidden_dependency" >&2
        exit 1
    fi
done

"$readelf_command" -n "$rapidgzip" > "$inspection_dir/notes.txt"
"$grep_command" -Fq 'x86 ISA needed: x86-64-baseline' "$inspection_dir/notes.txt"

"$nm_command" --defined-only "$rapidgzip" > "$inspection_dir/symbols.txt"
"$grep_command" -Fq 'rapidgzipCLI' "$inspection_dir/symbols.txt"
"$grep_command" -Eq '[[:space:]]inflate_fast_c$' "$inspection_dir/symbols.txt"
"$grep_command" -Eq '[[:space:]]crc32_gzip_refl_by16_10$' "$inspection_dir/symbols.txt"
"$grep_command" -Eq '[[:space:]]rpmalloc_thread_initialize$' "$inspection_dir/symbols.txt"

"$awk_command" '{ print $NF }' "$inspection_dir/symbols.txt" \
    > "$inspection_dir/symbol-names.txt"
if "$grep_command" -Eq '^(_?Py[A-Z_]|Py_|python)' "$inspection_dir/symbol-names.txt"; then
    echo "unexpected Python API symbol in native executable" >&2
    exit 1
fi
