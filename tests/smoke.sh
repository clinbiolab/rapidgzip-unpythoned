#!/bin/sh

set -eu

if [ "$#" -ne 5 ]; then
    echo "usage: smoke.sh RAPIDGZIP WORK_DIR GZIP CMP GREP" >&2
    exit 2
fi

rapidgzip=$1
work_dir=$2
gzip_command=$3
cmp_command=$4
grep_command=$5

# Keep all derived test data beneath the outer build tree.
mkdir -p "$work_dir"

"$rapidgzip" --version > "$work_dir/version.txt"
"$grep_command" -Fq "version 0.16.0" "$work_dir/version.txt"

"$rapidgzip" --help > "$work_dir/help.txt"
"$grep_command" -Fq -- "--version" "$work_dir/help.txt"
"$grep_command" -Fq -- "--oss-attributions" "$work_dir/help.txt"

printf '%s\n' \
    'rapidgzip-unpythoned production integration smoke test' \
    'file input and stdin must yield these exact bytes' \
    > "$work_dir/payload.txt"
"$gzip_command" -n -c "$work_dir/payload.txt" > "$work_dir/payload.txt.gz"

"$rapidgzip" -d -c "$work_dir/payload.txt.gz" > "$work_dir/file-output.txt"
"$cmp_command" "$work_dir/payload.txt" "$work_dir/file-output.txt"

"$rapidgzip" -d -c < "$work_dir/payload.txt.gz" > "$work_dir/stdin-output.txt"
"$cmp_command" "$work_dir/payload.txt" "$work_dir/stdin-output.txt"
