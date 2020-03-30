#!/bin/bash

set -e
if [ "$#" = 0 ]
then
    ALL=1
else
    while [[ $# -gt 0 ]]
    do
        key="$1"
        case $key in
            -p|--pacman)
                PACMAN=1
                shift
                ;;
            -a|--aur)
                AUR=1
                shift
                ;;
            -c|--cargo)
                CARGO=1
                shift
                ;;
            -y|--python)
                PYTHON=1
                shift
                ;;
        esac
    done
fi

function pac {
    [ "$ALL" = 1 ] || [ "$PACMAN" = 1 ]
}

function aur {
    [ "$ALL" = 1 ] || [ "$AUR" = 1 ]
}

function carg {
    [ "$ALL" = 1 ] || [ "$CARGO" = 1 ]
}

function pytho {
    [ "$ALL" = 1 ] || [ "$PYTHON" = 1 ]
}

script_dir="$(dirname "$(realpath "$0")")"

packages=()
aurpackages=()
bloat=()
cargopackages=()
pythonpackages=()
#shellcheck source=/home/mendess/Projects/spell-book/scrolls/packages.sh
. "$script_dir"/packages.sh

read -r -s -p "[sudo] password for $LOGNAME " PASSWORD

echo "$PASSWORD" | sudo -S true
pac && sudo pacman -S --noconfirm --downloadonly --needed "${packages[@]}"

echo "$PASSWORD" | sudo -S true
pac && sudo pacman -S --noconfirm --needed "${packages[@]}"

pac && for package in "${bloat[@]}"
do
    if pacman -Q "$package"
    then
        echo "$PASSWORD" | sudo -S true
        sudo pacman -Rsn --noconfirm "$package"
    fi
done

# Compton
pac && { ! pacman -Q xcompmgr ; } && {
    git clone https://github.com/tryone144/compton
    cd compton || exit 1
    make
    make docs
    echo "$PASSWORD" | sudo -S true
    sudo make install
    cd ..
    rm -rf compton
}

pac && {
    git clone https://github.com/BeMacized/scrot
    cd scrot || exit 1
    ./configure
    make
    sudo make install
    cd .. || exit 1
    rm -rf scrot
}

# Dash
echo "$PASSWORD" | sudo -S true
pac && sudo ln -sf /usr/bin/dash /usr/bin/sh

# Zathura as default pdf reader
xdg-mime default org.pwmt.zathura.desktop application/pdf

# (AUR manager)
aur && {
    mkdir tmp
    cd tmp || exit 1
    for i in "${aurpackages[@]}"
    do
        pacman -Q "$i" && continue
        old="$(pwd)"
        git clone https://aur.archlinux.org/"$i"
        cd "$i" || exit 1
        echo "$PASSWORD" | sudo -S true
        makepkg --syncdeps --install --noconfirm --skippgpcheck --clean
        cd "$old" || exit 1
    done
    cd ..
    rm -rf tmp
}

## NEOVIM
pac && nvim -c PlugInstall -c qall

## FIREFOX
pac &&
    sudo \
    sed -i \
    's|^Exec=/usr/lib/firefox/firefox|Exec=/home/mendess/.local/bin/crafted/firefox|' \
    /usr/share/applications/firefox.desktop

carg && {
    rustup default stable
    cargo install --force "${cargopackages[@]}"
}

pytho && {
    pip install --user "${pythonpackages[@]}"
}
cd "$script_dir" || exit 1
../spells/syncspellbook.spell
