#!/usr/bin/env bash
#|---/ /+------------------------------+---/ /|#
#|--/ /-| Script to patch custom theme |--/ /-|#
#|-/ /--| kRHYME7                      |-/ /--|#
#|/ /---+------------------------------+/ /---|#

print_prompt() {
    [[ "${verbose}" == "false" ]] && return 0
    while (("$#")); do
        case "$1" in
        -r)
            echo -ne "\e[31m$2\e[0m"
            shift 2
            ;; # Red
        -g)
            echo -ne "\e[32m$2\e[0m"
            shift 2
            ;; # Green
        -y)
            echo -ne "\e[33m$2\e[0m"
            shift 2
            ;; # Yellow
        -b)
            echo -ne "\e[34m$2\e[0m"
            shift 2
            ;; # Blue
        -m)
            echo -ne "\e[35m$2\e[0m"
            shift 2
            ;; # Magenta
        -c)
            echo -ne "\e[36m$2\e[0m"
            shift 2
            ;; # Cyan
        -w)
            echo -ne "\e[37m$2\e[0m"
            shift 2
            ;; # White
        -n)
            echo -ne "\e[96m$2\e[0m"
            shift 2
            ;; # Neon
        *)
            echo -ne "$1"
            shift
            ;;
        esac
    done
    echo ""
}

scrDir=$(dirname "$(realpath "$0")")
# shellcheck disable=SC1091
# if [ $? -ne 0 ]; then
if ! source "${scrDir}/global_fn.sh"; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

verbose="${4}"
set +e

# error function
ask_help() {
    cat <<HELP
Usage:
    $(print_prompt "$0 " -y "Theme-Name " -c "/Path/to/Configs")
    $(print_prompt "$0 " -y "Theme-Name " -c "https://github.com/User/Repository")
    $(print_prompt "$0 " -y "Theme-Name " -c "https://github.com/User/Repository/tree/branch")

Options:
    'export FORCE_THEME_UPDATE=true'       Overwrites the archived files (useful for updates and changes in gtk/icons/cursor archives)

Supported Archive Format:
    | File prfx       | Hyprland variable | Target dir                      |
    | --------------- | ----------------- | --------------------------------|
    | Gtk_            | \$GTK_THEME        | \$HOME/.local/share/themes     |
    | Icon_           | \$ICON_THEME       | \$HOME/.local/share/icons      |
    | Cursor_         | \$CURSOR_THEME     | \$HOME/.local/share/icons      |
    | Sddm_           | \$SDDM_THEME       | /usr/share/sddm/themes         |
    | Font_           | \$FONT             | \$HOME/.local/share/fonts      |
    | Document-Font_  | \$DOCUMENT_FONT    | \$HOME/.local/share/fonts      |
    | Monospace-Font_ | \$MONOSPACE_FONT   | \$HOME/.local/share/fonts      |
    | Waybar-Font_    | \$WAYBAR_FONT      | \$HOME/.local/share/fonts      |
    | Rofi-Font_      | \$ROFI_FONT        | \$HOME/.local/share/fonts      |

Note:
    Target directories without enough permissions will be skipped.
        run 'sudo chmod -R 777 <target directory>'
            example: 'sudo chmod -R 777 /usr/share/sddm/themes'
HELP
}

if [[ -z $1 || -z $2 ]]; then
    ask_help
    exit 1
fi

wallbashDirs=(
    "$HOME/.config/hyde/wallbash"
    "$HOME/.local/share/hyde/wallbash"
    "/usr/local/share/hyde/wallbash"
    "/usr/share/hyde/wallbash"
)

# set parameters
Fav_Theme="$1"

if [ -d "$2" ]; then
    Theme_Dir="$2"
else
    Git_Repo=${2%/}
    if echo "$Git_Repo" | grep -q "/tree/"; then
        branch=${Git_Repo#*tree/}
        Git_Repo=${Git_Repo%/tree/*}
    else
        branches=$(curl -s "https://api.github.com/repos/${Git_Repo#*://*/}/branches" | jq -r '.[].name')
        # shellcheck disable=SC2206
        branches=($branches)
        if [[ ${#branches[@]} -le 1 ]]; then
            branch=${branches[0]}
        else
            echo "Select a Branch"
            select branch in "${branches[@]}"; do
                [[ -n $branch ]] && break || echo "Invalid selection. Please try again."
            done
        fi
    fi

    Git_Path=${Git_Repo#*://*/}
    Git_Owner=${Git_Path%/*}
    branch_dir=${branch//\//_}
    cacheDir=${cacheDir:-"$HOME/.cache/hyde"}
    Theme_Dir="${cacheDir}/themepatcher/${branch_dir}-${Git_Owner}"

    if [ -d "$Theme_Dir" ]; then
        print_prompt "Directory $Theme_Dir already exists. Using existing directory."
        if cd "$Theme_Dir"; then
            git fetch --all &>/dev/null
            git reset --hard "@{upstream}" &>/dev/null
            cd - &>/dev/null || exit
        else
            print_prompt -y "Could not navigate to $Theme_Dir. Skipping git pull."
        fi
    else
        print_prompt "Directory $Theme_Dir does not exist. Cloning repository into new directory."
        if ! git clone -b "$branch" --depth 1 "$Git_Repo" "$Theme_Dir" &>/dev/null; then
            print_prompt "Git clone failed"
            exit 1
        fi
    fi
fi

print_prompt "Patching" -g " --// ${Fav_Theme} //-- " "from " -b "${Theme_Dir}\n"

Fav_Theme_Dir="${Theme_Dir}/Configs/.config/hyde/themes/${Fav_Theme}"
[ ! -d "${Fav_Theme_Dir}" ] && print_prompt -r "[ERROR] " "'${Fav_Theme_Dir}'" -y " Do not Exist" && exit 1

# config=$(find "${dcolDir}" -type f -name "*.dcol" | awk -v favTheme="${Fav_Theme}" -F 'theme/' '{gsub(/\.dcol$/, ".theme"); print ".config/hyde/themes/" favTheme "/" $2}')
config=$(find "${wallbashDirs[@]}" -type f -path "*/theme*" -name "*.dcol" 2>/dev/null | awk '!seen[substr($0, match($0, /[^/]+$/))]++' | awk -v favTheme="${Fav_Theme}" -F 'theme/' '{gsub(/\.dcol$/, ".theme"); print ".config/hyde/themes/" favTheme "/" $2}')
restore_list=""

while IFS= read -r fileCheck; do
    if [[ -e "${Theme_Dir}/Configs/${fileCheck}" ]]; then
        print_prompt -g "[found] " "${fileCheck}"
        fileBase=$(basename "${fileCheck}")
        fileDir=$(dirname "${fileCheck}")
        restore_list+="Y|Y|\${HOME}/${fileDir}|${fileBase}|hyprland\n"
    else
        print_prompt -y "[warn] " "${fileCheck} --> do not exist in ${Theme_Dir}/Configs/"
    fi
done <<<"$config"
if [ -f "${Fav_Theme_Dir}/theme.dcol" ]; then
    print_prompt -n "[note] " "found theme.dcol to override wallpaper dominant colors"
    restore_list+="Y|Y|\${HOME}/.config/hyde/themes/${Fav_Theme}|theme.dcol|hyprland\n"
fi
readonly restore_list

# Get Wallpapers
wallpapers=$(find "${Fav_Theme_Dir}" -type f \( -iname "*.gif" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \))
wpCount="$(echo "${wallpapers}" | wc -l)"
{ [ -z "${wallpapers}" ] && print_prompt -r "[ERROR] " "No wallpapers found" && exit_flag=true; } || { readonly wallpapers && print_prompt -g "\n[OK] " "wallpapers :: [count] ${wpCount} (.gif+.jpg+.jpeg+.png)"; }

# parse thoroughly 😁
check_tars() {
    local trVal
    local inVal="${1}"
    local gsLow
    local gsVal
    gsLow=$(echo "${inVal}" | tr '[:upper:]' '[:lower:]')
    # Use hyprland variables that are set in the hypr.theme file
    # Using case we can have a predictable output
    gsVal="$(
        case "${gsLow}" in
        sddm)
            grep "^[[:space:]]*\$SDDM[-_]THEME\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        gtk)
            grep "^[[:space:]]*\$GTK[-_]THEME\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        icon)
            grep "^[[:space:]]*\$ICON[-_]THEME\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        cursor)
            grep "^[[:space:]]*\$CURSOR[-_]THEME\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        font)
            grep "^[[:space:]]*\$FONT\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        document-font)
            grep "^[[:space:]]*\$DOCUMENT[-_]FONT\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        monospace-font)
            grep "^[[:space:]]*\$MONOSPACE[-_]FONT\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        waybar-font)
            grep "^[[:space:]]*\$WAYBAR[-_]FONT\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;
        rofi-font)
            grep "^[[:space:]]*\$ROFI[-_]FONT\s*=" "${Fav_Theme_Dir}/hypr.theme" | cut -d '=' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
            ;;

        *) # fallback to older method
            awk -F"[\"']" '/^[[:space:]]*exec[[:space:]]*=[[:space:]]*gsettings[[:space:]]*set[[:space:]]*org.gnome.desktop.interface[[:space:]]*'"${gsLow}"'-theme[[:space:]]*/ {last=$2} END {print last}' "${Fav_Theme_Dir}/hypr.theme"
            ;;
        esac
    )"

    # fallback to older method
    gsVal=${gsVal:-$(awk -F"[\"']" '/^[[:space:]]*exec[[:space:]]*=[[:space:]]*gsettings[[:space:]]*set[[:space:]]*org.gnome.desktop.interface[[:space:]]*'"${gsLow}"'-theme[[:space:]]*/ {last=$2} END {print last}' "${Fav_Theme_Dir}/hypr.theme")}

    if [ -n "${gsVal}" ]; then
        print_prompt -g "[OK] " "hypr.theme :: [${gsLow}]" -b " ${gsVal}"
        trArc="$(find "${Theme_Dir}" -type f -name "${inVal}_*.tar.*")"
        [ -f "${trArc}" ] && [ "$(echo "${trArc}" | wc -l)" -eq 1 ] && trVal="$(basename "$(tar -tf "${trArc}" | cut -d '/' -f1 | sort -u)")" && trVal="$(echo "${trVal}" | grep -w "${gsVal}")"
        print_prompt -g "[OK] " "../*.tar.* :: [${gsLow}]" -b " ${trVal}"
        [ "${trVal}" != "${gsVal}" ] && print_prompt -r "[ERROR] " "${gsLow}-theme set in hypr.theme does not exist in ${inVal}_*.tar.*" && exit_flag=true
    else
        [ "${2}" == "--mandatory" ] && print_prompt -r "[ERROR] " "hypr.theme :: [${gsLow}] Not Found" && exit_flag=true && return 0
        print_prompt -y "[warn] " "hypr.theme :: [${gsLow}] Not Found"
    fi
}

check_tars Gtk --mandatory
check_tars Icon
check_tars Cursor
check_tars Sddm
check_tars Font
check_tars Document-Font
check_tars Monospace-Font
check_tars Waybar-Font
check_tars Rofi-Font
print_prompt "" && [[ "${exit_flag}" = true ]] && exit 1

# extract arcs
declare -A archive_map=(
    ["Gtk"]="${HOME}/.local/share/themes"
    ["Icon"]="${HOME}/.local/share/icons"
    ["Cursor"]="${HOME}/.local/share/icons"
    ["Sddm"]="/usr/share/sddm/themes"
    ["Font"]="${HOME}/.local/share/fonts"
    ["Document-Font"]="${HOME}/.local/share/fonts"
    ["Monospace-Font"]="${HOME}/.local/share/fonts"
    ["Waybar-Font"]="${HOME}/.local/share/fonts"
    ["Rofi-Font"]="${HOME}/.local/share/fonts"
)

for prefix in "${!archive_map[@]}"; do
    tarFile="$(find "${Theme_Dir}" -type f -name "${prefix}_*.tar.*")"
    [ -f "${tarFile}" ] || continue
    tgtDir="${archive_map[$prefix]}"
    [ -d "${tgtDir}" ] || mkdir -p "${tgtDir}"
    tgtChk="$(basename "$(tar -tf "${tarFile}" | cut -d '/' -f1 | sort -u)")"
    [ -d "${tgtDir}/${tgtChk}" ] && print_prompt -y "[skip] " "\"${tgtDir}/${tgtChk}\" already exists" && continue
    print_prompt -g "[extracting] " "${tarFile} --> ${tgtDir}"
    tar -xf "${tarFile}" -C "${tgtDir}"
done

# populate wallpaper
confDir=${confDir:-"$HOME/.config"}
Fav_Theme_Walls="${confDir}/hyde/themes/${Fav_Theme}/wallpapers"
[ ! -d "${Fav_Theme_Walls}" ] && mkdir -p "${Fav_Theme_Walls}"
while IFS= read -r walls; do
    cp -f "${walls}" "${Fav_Theme_Walls}"
done <<<"${wallpapers}"

# restore configs with theme override
echo -en "${restore_list}" >"${Theme_Dir}/restore_cfg.lst"
print_prompt -g "\n[exec] " "restore_cfg.sh \"${Theme_Dir}/restore_cfg.lst\" \"${Theme_Dir}/Configs\" \"${Fav_Theme}\"\n"
"${scrDir}/restore_cfg.sh" "${Theme_Dir}/restore_cfg.lst" "${Theme_Dir}/Configs" "${Fav_Theme}" &>/dev/null
if [ "${3}" != "--skipcaching" ]; then
    "$HOME/.local/lib/hyde/swwwallcache.sh" -t "${Fav_Theme}"
    "$HOME/.local/lib/hyde/themeswitch.sh"
fi

print_prompt -y "\nNote: Warnings are not errors. Review the output to check if it concerns you."

exit 0
