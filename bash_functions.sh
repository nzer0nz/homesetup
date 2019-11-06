#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034

#  Script: bash_functions.sh
# Purpose: This file is used to define some shell tools
# Created: Aug 26, 2008
#  Author: <B>H</B>ugo <B>S</B>aporetti <B>J</B>unior
#  Mailto: yorevs@hotmail.com
#    Site: https://github.com/yorevs/homesetup
# License: Please refer to <http://unlicense.org/>
# !NOTICE: Do not change this file. To customize your functions edit the file ~/.functions

# Fontawesome icons
CROSS_ICN="\xef\x81\x97"
CHECK_ICN="\xef\x81\x98"
STAR_ICN="\xef\x80\x85"

# Dependencies
[ -f "$HOME/.bash_env" ] && \. "$HOME/.bash_env"
[ -f "$HOME/.bash_colors" ] && \. "$HOME/.bash_colors"
[ -f "$HOME/.bash_aliases" ] && \. "$HOME/.bash_aliases"

# Load all function files prefixed with 'hhs-`
# shellcheck disable=SC2044
for file in $(find "${HOME_SETUP}/bin/hhs-functions" -type f -name "hhs-*.sh" | sort); do
    \. "$file";
done;

# To check for all functions provided by HHS issue the following command: 
__hhs() {

    local pad
    local pad_len=30

    pad=$(printf '%0.1s' "."{1..30})
    all_fn=$(ss "${HOME_SETUP}" "function __hhs_" "hhs-*.sh" | awk "NR != 1 {print \$1 \$2}")

    shopt -s nocasematch
    if [ "$1" = "help" ] && [ -n "$2" ]; then
        # If the function exists, invoke it's help
        if [[ ${all_fn} == *"$2"* ]]; then
            #echo "Found help for: $(echo ${all_fn} | awk -F: '/regex/ { $2; print $0 }')"
            eval "${2} -h"
        else
            echo "Usage: ${FUNCNAME[0]} [help <hhs-function-name>]"
            echo ''
            echo 'If no argument is passed, lists all available hhs-functions'
        fi
    else
        echo -e "\n${ORANGE}HomeSetup available functions -------------------------------------\n"
        for fn in $all_fn; do
            filename=$(basename "$fn" | awk -F ":function" '{print $1}')
            fnname=$(awk -F ":function" '{print $2}' <<< "$fn")
            echo -en "${WHITE}${BLUE}${filename}"
            printf '%*.*s' 0 $((pad_len - ${#filename})) "$pad"
            echo -e "${WHITE} => ${GREEN}${fnname//\(\)/}"
        done
        echo -e "\n${YELLOW}${STAR_ICN} To display help about a function type: #> ${GREEN}__hhs help <function_name>"
    fi
    echo "${NR}"
    shopt -u nocasematch

    return 0
}
