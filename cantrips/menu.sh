#!/bin/bash
cd "$(dirname "$(realpath "$0")")" || exit 1

./"$(find . -name '*.sh' -executable |
    grep -v 'menu' |
    sed 's|./||g;s/\.sh$//g' |
    sort -r |
    dmenu -i -p "Pick a menu:" -l 100)".sh "$1" &
disown
