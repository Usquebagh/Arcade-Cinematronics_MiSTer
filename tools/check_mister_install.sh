#!/bin/bash
# Read-only installation check. No ROM contents are read or changed.
# Run via SSH: bash /media/fat/Scripts/check_mister_install.sh
# Optional argument: storage root (default /media/fat).
set -u
export LC_ALL=C
card_root=${1:-/media/fat}
expected_sha=b6ec1d9c17728e2b59c23b0522e6ccdd60386904e206327dcb14317dfb4b431d
expected_build=20261011

printf 'Cinematronics installation check\nStorage: %s\n' "$card_root"
if [ ! -d "$card_root" ]; then
    printf 'FAIL: storage directory does not exist\n'
    exit 1
fi

check_mra() {
    local mra=$1 fragment prefix arcade_root cores selected candidate base actual_sha
    printf '\nMRA: %s\n' "$mra"
    if head -c 1024 "$mra" | grep -qiE '<!DOCTYPE html|<html'; then
        printf 'FAIL: this MRA is an HTML webpage, not an MRA XML file\n'
        printf 'Download the raw file from GitHub; saving the file page saves HTML.\n'
        return 1
    fi
    fragment=$(sed -n 's/.*<rbf>\([^<]*\)<\/rbf>.*/\1/p' "$mra" | head -n 1)
    printf 'RBF tag: <%s>\n' "$fragment"
    if [ -z "$fragment" ]; then
        printf 'FAIL: no single-line rbf tag found; inspect this MRA\n'
        return 1
    fi
    # Main_MiSTer uses the first /_ directory in the absolute MRA path.
    prefix=${mra%%/_*}
    if [ "$prefix" = "$mra" ]; then
        arcade_root=$card_root
    else
        # Keep the first directory following /_; nested MRA folders do not count.
        arcade_root=${mra#"$prefix/"}
        arcade_root="$prefix/${arcade_root%%/*}"
    fi
    cores="$arcade_root/cores"
    printf 'MiSTer searches: %s\n' "$cores"
    selected=
    if [ -d "$cores" ]; then
        while IFS= read -r candidate; do
            base=${candidate##*/}
            case "${base,,}" in
                "arcade-${fragment,,}.rbf"|"arcade-${fragment,,}_"*.rbf|"${fragment,,}.rbf"|"${fragment,,}_"*.rbf)
                    printf 'Matching RBF: %s\n' "$candidate"
                    if [ -z "$selected" ] || [[ "$base" > "${selected##*/}" ]]; then
                        selected=$candidate
                    fi
                    ;;
            esac
        done < <(find "$cores" -maxdepth 1 -type f -iname '*.rbf')
    fi
    if [ -z "$selected" ]; then
        printf 'FAIL: no matching RBF in the directory MiSTer searches\n'
        return 1
    fi
    printf 'Selected RBF: %s\nBytes: ' "$selected"
    wc -c < "$selected"
    actual_sha=$(sha256sum "$selected" | cut -d ' ' -f 1)
    printf 'SHA256: %s\n' "$actual_sha"
    if head -c 1024 "$selected" | grep -qiE '<!DOCTYPE html|<html'; then
        printf 'FAIL: this RBF is an HTML webpage, not an FPGA bitstream\n'
        printf 'Download the raw file from GitHub; saving the file page saves HTML.\n'
        return 1
    fi
    if [ "$actual_sha" = "$expected_sha" ]; then
        printf 'PASS: identical to build %s\n' "$expected_build"
    else
        printf 'FAIL: not identical to the current build %s\n' "$expected_build"
        return 1
    fi
}

found=0
failed=0
mra_root=$card_root
if [ -d "$card_root/_Arcade" ]; then mra_root="$card_root/_Arcade"; fi
while IFS= read -r mra; do
    found=1
    check_mra "$mra" || failed=1
done < <(find "$mra_root" -type d \( -iname mame -o -iname cores \) -prune -o \
    -type f \( -iname '*star*castle*.mra' -o -iname '*rip*off*.mra' -o -iname '*armor*attack*.mra' \) -print)
if [ "$found" = 0 ]; then
    printf 'FAIL: no Star Castle, Rip Off or Armor Attack MRA found on this storage\n'
    failed=1
fi
printf '\nThis checks installed paths and files; FPGA startup still needs a launch test.\n'
if [ -t 0 ]; then
    read -r -p 'Press Enter to finish. ' _reply
fi
exit "$failed"
