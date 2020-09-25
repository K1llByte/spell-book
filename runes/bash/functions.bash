#!/bin/bash

#shellcheck source=/home/mendess/.local/bin/library
. library

make() {
    if [ -e Makefile ] || [ -e makefile ]; then
        bash -c "make -j$(nproc || echo 4) $*"
    else
        for i in *.c; do
            file=${i//\.c/}
            bash -c "make $file"
        done
    fi
}

ex() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz) tar xzf "$1" ;;
            *.bz2) bunzip2 -v "$1" ;;
            *.rar) unrar x "$1" ;;
            *.gz) gunzip "$1" ;;
            *.tar) tar xf "$1" ;;
            *.tbz2) tar xjf "$1" ;;
            *.tgz) tar xzf "$1" ;;
            *.zip) unzip "$1" ;;
            *.Z) uncompress "$1" ;;
            *.7z) 7z x "$1" ;;
            *.xz) xz -d "$1" ;;
            *) echo "$1 cannot be extracted via ex()" ;;
        esac
    else
        echo "$1 is not a valid file"
    fi
}

__append_to_recents() { # $1 line, $2 recents file
    mkdir -p ~/.cache/my_recents
    touch ~/.cache/my_recents/"$2"
    echo "$1" | cat - ~/.cache/my_recents/"$2" | awk '!seen[$0]++' | head -10 >temp && mv temp ~/.cache/my_recents/"$2"
}

__run_disown() {
    local file="$2"
    if [ "$file" = "" ] && [ -f ~/.cache/my_recents/"$1" ]; then
        file=$(sed -e 's/\/home\/mendess/~/' ~/.cache/my_recents/"$1" | dmenu -i -l "$(wc -l ~/.cache/my_recents/"$1")")
        [ "$file" = "" ] && return 1
        file=$HOME${file//\~//}
    fi
    file="$(realpath "$file")"
    "$1" "$file" &>/dev/null &
    disown
    [ -e "$file" ] && __append_to_recents "$file" "$1"
}

pdf() {
    __run_disown zathura "$1" && exit
}

za() {
    __run_disown zathura "$1"
}

alarm() {
    if [ $# -lt 1 ]; then
        echo provide a time string
        return 1
    fi
    {
        link="https://www.youtube.com/watch?v=4iC-7aJ6LDY"
        sleep "$1"
        mpv --no-video "$link" --input-ipc-server=/tmp/mpvalarm &
        notify-send -u critical "Alarm" "$2" -a "$(basename "$0")"
    } &
    disown
}

matrix() {
    echo -e "\e[1;40m"
    clear
    while :; do
        echo $LINES $COLUMNS $((RANDOM % COLUMNS)) $((RANDOM % 72))
        sleep 0.05
    done |
        awk '{ letters="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*()"; c=$4; letter=substr(letters,c,1);a[$3]=0;for (x in a) {o=a[x];a[x]=a[x]+1; printf "\033[%s;%sH\033[2;32m%s",o,x,letter; printf "\033[%s;%sH\033[1;37m%s\033[0;0H",a[x],x,letter;if (a[x] >= $1) { a[x]=0; } }}'
}

loop() {
    n=""
    while ! [ "$n" = "n" ]; do
        "$@"
        read -r n
    done
}

clearswap() {
    local drive
    drive="$(lsblk -i | grep SWAP | awk '{print $1}' | sed -r 's#[|`]-#/dev/#')"
    sudo swapoff "$drive"
    sudo swapon "$drive"
}

vimbd() {
    vimb "$1" &
    disown
    exit
}

svim() {
    cd "$SPELLS" || return 1
    if [ -n "$1" ]; then
        "$EDITOR" "$1"
    else
        local DIR
        DIR="$(find . -type f |
            grep -vP '\.git|library' |
            sed 's|^./||g' |
            fzf)"
        [ -n "$DIR" ] && "$EDITOR" "$DIR"
        cd - &>/dev/null || return 1
    fi
}

k() {
    if lsusb | grep -E 'Mechanical|Keyboard|Kingston' &>/dev/null; then
        setxkbmap us -option caps:escape
        xmodmap -e 'keycode  21 = plus equal plus equal'
    else
        setxkbmap pt -option caps:escape
    fi
}

advent-of-code() {
    if [[ "$1" != day* ]]; then
        echo "bad input: '$1'"
        return 1
    fi
    cargo new "$1" || return 1
    cd "$1" || return 1
    echo '
[[bin]]
name = "one"
path = "src/one.rs"

[[bin]]
name = "two"
path = "src/two.rs"' >>Cargo.toml
    cp src/main.rs src/one.rs
    cp src/main.rs src/two.rs
    rm src/main.rs
}

degen() {
    python3 -c '
from random import choice
from sys import argv
print("".join((map(lambda x: x.upper() if choice([True, False]) else x.lower(), " ".join(argv[1:])))))
' "$@"
}

record() {
    if [ "$1" = right ]; then
        i=1920
    else
        i=0
    fi
    ffmpeg \
        -video_size 1920x1080 \
        -framerate 60 \
        -f x11grab \
        -i :0.0+$i,0 \
        "output-$(date +"%d_%m_%Y_%H_%M").mp4"
}

share() {
    FILE="$1"
    [ "$2" ] && filename="$2" || filename="$(basename "$FILE")"
    if [ -d "$FILE" ]; then
        zip -r "/tmp/$filename.zip" "$FILE"
        FILE="/tmp/$filename.zip"
    fi
    scp "$FILE" "mirrodin:~/disk0/Mirrodin/serve/$filename"
    url="http://mendess.xyz/file/$filename"
    if command -v termux-clipboard-set; then
        echo -n "$url" | termux-clipboard-set
    else
        echo -n "$url" | xclip -sel clip
    fi
    echo "$url"
}

connect() {
    if [ $# -lt 2 ]; then
        echo "Usage: $0 ssid password"
        return
    fi
    nmcli device wifi connect "$1" password "$2"
}

gcl() {
    case "$1" in
        http://*)
            echo '============================> using http'
            git clone "$1" "${@:2}"
            ;;
        git@* | https://*)
            git clone "$1" "${@:2}"
            ;;
        */*)
            git clone git@github.com:"$1" "${@:2}"
            ;;
        *)
            git clone git@github.com:"$(git config --global user.name)"/"$1" "${@:2}"
            ;;
    esac
}

nospace() {
    for file in *; do
        grep ' ' <(echo "$file") || continue
        mv -vn "$file" "$(echo "$file" | sed -r "s/['&,()!]//g;s/ ([-_]) /\\1/g;s/ /_/g;s/_+/_/g")"
    done
}

xdofast() {
    export DISPLAY=:0
    echo "alias x='xdotool'"
    echo "alias xk='xdotool key'"
    echo "alias xt='xdotool type'"
    alias x='xdotool'
    alias xk='xdotool key'
    alias xt='xdotool type'
}

mpvy() {
    mpv --no-video "ytdl://ytsearch:$*"
}

mpvys() {
    mpvs "ytdl://ytsearch:$*"
}

mpvyv() {
    mpv "ytdl://ytsearch:$*"
}

mpvysv() {
    mpvsv "ytdl://ytsearch:$*"
}

mpv_get() {
    #shellcheck source=/home/mendess/.local/bin/library
    . library

    #shellcheck disable=2119
    echo '{ "command": ["get_property", "'"$1"'"] }' |
        socat - "$(m socket)" |
        jq "${2:-.}"
}

any() {
    find "${1:-.}" -maxdepth 1 | shuf -n 1
}

insist() {
    until eval "$@"; do :; done
}

nest() {
    tmp=..
    [ "$PWD" = / ] && tmp=/tmp
    dir="$tmp/$1"
    echo "Gonna create $1 at $dir and move stuff there"
    mkdir "$dir" || return
    mv "${@:2}" "$dir" || return
    mv "$dir" . || return
}

lyrics() {
    curl -s --get "https://makeitpersonal.co/lyrics" \
        --data-urlencode "title='${*:2}'" \
        --data-urlencode "artist=$1"
}

fcd() {
    local dir
    for i in {0..64}; do
        printf "depth: %d" $i
        dir="$(find -L . -maxdepth "$i" -type d ! -path './.*' |
            grep -i "$*" |
            head -1)"
        printf "\r\e[K"
        if [ -n "$dir" ]; then
            cd "$dir" || continue
            break
        fi
    done
}

latex_ignore() {
    cat <<EOF
*.toc
*.aux
*.log
*.pdf
*.html
*.bbl
*.blg
_minted-presentation/
*.nav
*.out
*.snm
*.vrb
EOF
}

sleep_now() {
    {
        while ! m c | grep '0%'; do
            sleep 1m
            m vd
        done
    } &
    disown
    ssh mirrodin python bulb/dimmer.py 0 &
    disown
    (
        sleep 2m
        DISPLAY=:0 xset dpms force off
    ) &
    sleep "${1:-40m}"
    sctl suspend
}

die_now() {
    { while :; do
        sleep 1m
        m vd
    done; } &
    disown
    ssh mirrodin python bulb/dimmer.py 0 &
    disown
    (
        sleep 2m
        DISPLAY=:0 xset dpms force off
    ) &
    shutdown +"${1:-40}"
}

sshp() {
    ssh "$1" '. $HOME/.bash_profile; '"${*:2}"
}

torrent() {
    while
        transmission-cli "$1" "${@:2}"
        ! read -r -t 2 -p "Quit?"
    do :; done
}

function songs() {
    grep -P '.+\t.+\t[0-9]+\t.*'"$1" "$PLAYLIST" |
        awk -F'\t' '{print $2" :: "$1}'
}

3_simple() {
    l1="$1"
    r1="$2"
    l2="$3"
    r2="${4:-x}"
    if [ "$l2" = x ]; then
        echo "($r2 * $l1) / $r1" | bc -l
    elif [ "$r2" = x ]; then
        echo "($l2 * $r1) / $l1" | bc -l
    else
        echo "Error needs at least one x"
    fi
}
