#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
cyan='\033[0;36m'
nc='\033[0m'

infoMsg() { echo -e "${green}[INFO]${nc}  $*"; }
warnMsg() { echo -e "${yellow}[WARN]${nc}  $*"; }
errMsg() { echo -e "${red}[FAIL]${nc}  $*"; }

stateDir="/var/lib/visnux-update"
stateFile="${stateDir}/last-commit"
workDir=""
updateFailed=0
grubChanged=0

cleanupFn() {
    if [ -n "$workDir" ] && [ -d "$workDir" ]; then
        rm -rf "$workDir"
    fi
}

trap cleanupFn EXIT

if ! mkdir -p "$stateDir" 2>/dev/null || ! touch "${stateDir}/.writetest" 2>/dev/null; then
    if [ "$(id -u)" -ne 0 ]; then
        warnMsg "No write access, re-running with sudo..."
        exec sudo "$0" "$@"
    fi

    errMsg "Still no write access to ${stateDir} as root."
    exit 1
fi

rm -f "${stateDir}/.writetest" 2>/dev/null

if ! command -v git &>/dev/null; then
    errMsg "'git' not found. Install it first: pacman -S git"
    exit 1
fi

if ! command -v flock &>/dev/null; then
    errMsg "'flock' not found. Install util-linux first."
    exit 1
fi

exec 9>/run/visnux-update.lock

if ! flock -n 9; then
    errMsg "Another Visnux update is already running."
    exit 1
fi

echo ""
echo -e "${cyan}=== Visnux System Update ===${nc}"
echo ""

workDir="$(mktemp -d /tmp/visnux-update.XXXXXX)"
larphubDir="${workDir}/larphub"

infoMsg "Fetching latest larphub..."

if ! git clone --quiet --depth 1 https://github.com/realv1sta/larphub "$larphubDir" 2>/dev/null; then
    errMsg "Failed to clone larphub. Check your internet connection."
    exit 1
fi

if [ ! -f "${larphubDir}/visnuxinstall.sh" ]; then
    errMsg "Repository does not appear to be a Visnux repository."
    exit 1
fi

latestCommit="$(git -C "$larphubDir" rev-parse HEAD)"

if [ -f "$stateFile" ]; then
    lastCommit="$(head -n 1 "$stateFile")"
else
    lastCommit=""
fi

if [ "$latestCommit" = "$lastCommit" ]; then
    infoMsg "Already up to date (commit ${latestCommit:0:8})."
    exit 0
fi

if [ -n "$lastCommit" ]; then
    infoMsg "Update available: ${lastCommit:0:8} -> ${latestCommit:0:8}"
else
    infoMsg "No previous update recorded. Performing initial sync."
fi

echo ""

if [ -d "${larphubDir}/neveraskmewhatthisis/Office-sidebar" ]; then
    infoMsg "Updating GRUB theme..."

    grubThemeTemp="${workDir}/Office-sidebar"

    if ! cp -r "${larphubDir}/neveraskmewhatthisis/Office-sidebar" "$grubThemeTemp"; then
        errMsg "Failed to prepare GRUB theme."
        updateFailed=1
    else
        mkdir -p /boot/grub/themes

        if ! rm -rf /boot/grub/themes/Office-sidebar.old \
            || ! mv /boot/grub/themes/Office-sidebar /boot/grub/themes/Office-sidebar.old 2>/dev/null \
            || ! mv "$grubThemeTemp" /boot/grub/themes/Office-sidebar; then

            rm -rf /boot/grub/themes/Office-sidebar

            if [ -d /boot/grub/themes/Office-sidebar.old ]; then
                mv /boot/grub/themes/Office-sidebar.old /boot/grub/themes/Office-sidebar
            fi

            errMsg "Failed to update GRUB theme."
            updateFailed=1
        else
            rm -rf /boot/grub/themes/Office-sidebar.old
            grubChanged=1
        fi
    fi
else
    warnMsg "GRUB theme folder not found, skipping."
fi

if [ -f "${larphubDir}/visnux.svg" ]; then
    infoMsg "Updating visnux.svg..."

    iconDir="/usr/share/icons/hicolor/scalable/apps"
    iconFile="${iconDir}/visnux.svg"

    mkdir -p "$iconDir"

    if ! cmp -s "${larphubDir}/visnux.svg" "$iconFile" 2>/dev/null; then
        if ! cp "${larphubDir}/visnux.svg" "$iconFile"; then
            errMsg "Failed to update visnux.svg."
            updateFailed=1
        fi
    else
        infoMsg "visnux.svg unchanged."
    fi
else
    warnMsg "visnux.svg not found, skipping."
fi

if [ -f "${larphubDir}/visnux.png" ]; then
    infoMsg "Updating visnux.png..."

    pixmapDir="/usr/share/pixmaps"
    pixmapFile="${pixmapDir}/visnux.png"

    mkdir -p "$pixmapDir"

    if ! cmp -s "${larphubDir}/visnux.png" "$pixmapFile" 2>/dev/null; then
        if ! cp "${larphubDir}/visnux.png" "$pixmapFile"; then
            errMsg "Failed to update visnux.png."
            updateFailed=1
        fi
    else
        infoMsg "visnux.png unchanged."
    fi
else
    warnMsg "visnux.png not found, skipping."
fi

if [ -d "${larphubDir}/walls/visnux-walls" ]; then
    infoMsg "Updating wallpapers..."

    wallpaperDir="/usr/share/wallpapers"
    backgroundDir="/usr/share/backgrounds/visnux"
    wallpaperTemp="${workDir}/wallpapers"

    mkdir -p "$wallpaperTemp"
    mkdir -p "$wallpaperDir"
    mkdir -p "$backgroundDir"

    if ! cp -r "${larphubDir}/walls/visnux-walls/." "$wallpaperTemp/"; then
        errMsg "Failed to prepare wallpapers."
        updateFailed=1
    else
        rm -rf "${wallpaperDir}/visnux-walls"
        rm -rf "${backgroundDir}/visnux-walls"

        if ! cp -r "$wallpaperTemp/." "$wallpaperDir/" \
            || ! cp -r "$wallpaperTemp/." "$backgroundDir/"; then
            errMsg "Failed to update wallpapers."
            updateFailed=1
        fi
    fi
else
    warnMsg "Wallpaper folder not found, skipping."
fi

fastfetchDir="/etc/skel/.config/fastfetch"

if [ -f "${larphubDir}/neveraskmewhatthisis/config.jsonc" ]; then
    infoMsg "Updating fastfetch config..."

    mkdir -p "$fastfetchDir"

    if ! cmp -s \
        "${larphubDir}/neveraskmewhatthisis/config.jsonc" \
        "${fastfetchDir}/config.jsonc" 2>/dev/null; then

        if ! cp \
            "${larphubDir}/neveraskmewhatthisis/config.jsonc" \
            "${fastfetchDir}/config.jsonc"; then

            errMsg "Failed to update fastfetch config."
            updateFailed=1
        fi
    else
        infoMsg "Fastfetch config unchanged."
    fi
else
    warnMsg "Fastfetch config not found, skipping."
fi

if [ -x "${larphubDir}/colorlogo.sh" ]; then
    infoMsg "Updating fastfetch logo..."

    mkdir -p "$fastfetchDir"

    logoTemp="${workDir}/logo.txt"

    if ! (cd "$larphubDir" && ./colorlogo.sh > "$logoTemp"); then
        errMsg "Failed to generate fastfetch logo."
        updateFailed=1
    elif [ ! -s "$logoTemp" ]; then
        errMsg "Fastfetch logo generator produced no output."
        updateFailed=1
    elif ! cmp -s "$logoTemp" "${fastfetchDir}/logo.txt" 2>/dev/null; then
        if ! cp "$logoTemp" "${fastfetchDir}/logo.txt"; then
            errMsg "Failed to update fastfetch logo."
            updateFailed=1
        fi
    else
        infoMsg "Fastfetch logo unchanged."
    fi
else
    warnMsg "colorlogo.sh not found or not executable, skipping."
fi

if [ "$grubChanged" -eq 1 ]; then
    if command -v grub-mkconfig &>/dev/null; then
        infoMsg "Regenerating GRUB config..."

        if ! grub-mkconfig -o /boot/grub/grub.cfg; then
            errMsg "grub-mkconfig failed."
            updateFailed=1
        fi
    else
        warnMsg "grub-mkconfig not found, skipping."
    fi
fi

if [ "$updateFailed" -eq 1 ]; then
    echo ""
    errMsg "Update finished with errors (commit ${latestCommit:0:8} NOT marked as synced)."
    exit 1
fi

stateTemp="${stateFile}.tmp"

if ! printf '%s\n' "$latestCommit" > "$stateTemp"; then
    errMsg "Failed to write update state."
    rm -f "$stateTemp"
    exit 1
fi

if ! mv -f "$stateTemp" "$stateFile"; then
    errMsg "Failed to save update state."
    rm -f "$stateTemp"
    exit 1
fi

echo ""
infoMsg "Update complete (commit ${latestCommit:0:8})"
