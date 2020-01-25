#!/usr/bin/env bash

#  Script: hhs-minput.bash
# Created: Jan 16, 2020
#  Author: <B>H</B>ugo <B>S</B>aporetti <B>J</B>unior
#  Mailto: yorevs@hotmail.com
#    Site: https://github.com/yorevs/homesetup
# License: Please refer to <http://unlicense.org/>
# !NOTICE: Do not change this file. To customize your functions edit the file ~/.functions

# rl; \rm -f /tmp/out.txt; minput /tmp/out.txt "Name:input:alphanumeric:10/30:rw:" "Password:password:any:8/30:rw:" "Age:input:number:1/3::" "Role:::5:r:Admin"

# @function: Retrieve the current cursor position on screen. ## This is a very expensive call
function __hhs_minput_curpos() {

  local row col
  
  # Sometimes the cursor position is not comming, so make sure we have data to retrieve
  while
    [ -z "$row" ] || [ -z "$col" ]
    exec < /dev/tty
    disable-echo
    echo -en "\033[6n" > /dev/tty
    IFS=';' read -r -d R -a pos
    enable-echo
    if [[ ${#pos} -gt 0 ]]; then
      row="${pos[0]:2}"
      col="${pos[1]}"
      if [[ $row =~ ^[1-9]+$ ]] && [[ $col =~ ^[1-9]+$ ]]; then
        echo "$((row - 1)),$((col - 1))"
        return 0
      else
        unset row
        unset col
      fi
    fi
  do :; done

  return 1
}

# @function: Validate a keypress against an input according to it's type
function __hhs_minput_validate() {

  local val_regex f_type="$1" keypress="$2"

  # Append value to the current field if the value matches the input type
  case "${f_type}" in
    'letter') val_regex='^[a-zA-Z ]*$' ;;
    'number') val_regex='^[0-9]*$' ;;
    'alphanumeric') val_regex='^[a-zA-Z0-9 ]*$' ;;
    *) val_regex='.*' ;;
  esac

  if [[ "${keypress}" =~ ${val_regex} ]]; then
    return 0
  else
    return 1
  fi
}

# @function: Select an option from a list using a navigable menu.
# @param $1 [Req] : The response file.
# @param $2 [Req] : The form fields.
function __hhs_minput() {

  UNSELECTED_BG='\033[40m'
  SELECTED_BG='\033[44m'

  if [[ $# -eq 0 ]] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    echo "Usage: ${FUNCNAME[0]} <output_file> <fields...>"
    echo ''
    echo '    Arguments: '
    echo '      output_file : The output file where the result will be stored.'
    echo '        fields    : A list of form fields: Label:Mode:Type:Minlen/Maxlen:Perm:Value'
    echo ''
    echo '    Fields: '
    echo '            <Label> : The field label.'
    echo '             [Mode] : The input mode. One of {[input]|password}.'
    echo '             [Type] : The input type. One of {letter|number|alphanumeric|[any]}.'
    echo '      [Max/Min len] : The maximum and minimum amount of characters allowed to be typed [0/30].'
    echo '             [Perm] : The field permissions. One of {r|[rw]} where (r : Read Only ; rw : Read & Write).'
    echo '            [Value] : The initial value of the field.'
    echo ''
    echo '  Notes: '
    echo '    - Optional fields will assume a default value if they are not specified.'
    echo '    - A temporary file is suggested to used with this command: #> mktemp.'
    echo '    - The outfile must not exist or be an empty file.'
    echo ''
    echo '  Examples: '
    echo '    minput /tmp/out.txt "Name:::5/30:rw:" "Age::number:1/3::" "Password:password::5:rw:" "Role:::::Admin"'
    return 1
  fi

  local outfile="${1}" re_render=1 label_size value_size all_fields=() cur_field=() field_parts=()
  local f_label f_mode f_type f_max_min_len f_perm f_value f_row f_col f_pos err_msg dismiss_timeout
  local len minlen offset margin maxlen idx tab_index cur_row cur_col val_regex exit_pos all_pos=()

  if [ -d "$1" ] || [ -s "$1" ]; then
    echo -e "${RED}\"$1\" is a directory or an existing non-empty file !${NC}"
    return 1
  fi
  
  shift
  
  # TODO: Validate field syntax => "Label:Mode:Type:Max/Min:Perm:Value" ...{
  all_fields=("${@}")
  label_size=10 # TODO find dinamically the greater Label length
  value_size=30 # TODO find dinamically the greater Value maxlen
  # }
  
  len=${#all_fields[*]}
  disable-line-wrap
  tab_index=0
  clear 
  
  echo -e "${YELLOW}Please fill all fields of the form below${NC}"
  echo ''
  save-cursor-pos
  
  while :; do

    # Menu Renderization {
    if [ -n "$re_render" ]; then
      hide-cursor
      # Restore the cursor to the home position
      restore-cursor-pos
      enable-echo
      for idx in "${!all_fields[@]}"; do
        IFS=':'
        field="${all_fields[$idx]}"
        read -rsa field_parts <<< "${field}"
        f_label="${field_parts[0]}"
        f_mode="${field_parts[1]}"
        f_mode=${f_mode:-input}
        f_type="${field_parts[2]}"
        f_type=${f_type:-any}
        f_max_min_len="${field_parts[3]}"
        f_max_min_len="${f_max_min_len:-0/30}"
        maxlen=${f_max_min_len##*/}
        f_perm="${field_parts[4]}"
        f_perm=${f_perm:-rw}
        f_value="${field_parts[5]}"
        if [[ $tab_index -ne $idx ]]; then
          printf "${UNSELECTED_BG}%${label_size}s: " "${f_label}"
        else
          printf "${SELECTED_BG}%${label_size}s: " "${f_label}"
          # Buffering the cursor all positions to avoid calling __hhs_minput_curpos
          f_pos="${all_pos[$idx]:-$(__hhs_minput_curpos)}"
          f_row="${f_pos%,*}"
          f_col="${f_pos#*,}"
          f_col="$((f_col + ${#f_value}))"
          all_pos[$idx]="${f_pos}"
        fi
        offset=${#f_value}
        margin=$((12 - (${#maxlen} + ${#offset})))
        [ "input" = "${f_mode}" ] && printf "%-${value_size}s" "${f_value}"
        [ "password" = "${f_mode}" ] && printf "%-${value_size}s" "$(sed -E 's/./\*/g' <<< "${f_value}")"
        printf "  %d/%d" "${#f_value}" "${maxlen}"
        printf "%*.*s${UNSELECTED_BG}\033[0K" 0 "${margin}" "$(printf '%0.1s' " "{1..60})"
        # Display any previously set error message
        if [[ $tab_index -eq $idx ]] && [ -n "${err_msg}" ]; then
          err_msg="  <<< ${err_msg}"
          dismiss_timeout=$((1 + (${#err_msg} / 25)))
          echo -en "${UNSELECTED_BG}${RED}${err_msg}"
          disable-echo
          # Discard any garbage typed by the user while showing the error
          IFS= read -rsn1000 -t ${dismiss_timeout} err_msg < "/dev/tty"
          enable-echo
          echo -en "\033[${#err_msg}D\033[0K${NC}" # Remove the message after the timeout
          unset err_msg
        fi
        echo -e '\n'
        # Keep the selected field on hand
        if [[ $tab_index -eq $idx ]]; then
          # shellcheck disable=SC2206
          cur_field=(${field_parts[@]})
          cur_row="${f_row}"
          cur_col="${f_col}"
        fi
        # Update the field with the default values if required
        all_fields[$idx]="${f_label}:${f_mode}:${f_type}:${f_max_min_len}:${f_perm}:${f_value}"
        IFS="$HHS_RESET_IFS"
      done
      echo -e "${UNSELECTED_BG}"
      echo -en "${YELLOW}[Enter] Submit  [↑↓] Navigate  [TAB] Next  [Esc] Quit \033[0K"
      echo -en "${NC}"
      exit_pos=${exit_pos:-$(__hhs_minput_curpos)}
      unset re_render
      # Position the cursor on the current tab index
      tput cup "${cur_row}" "${cur_col}"
    fi
    # } Menu Renderization

    # Navigation input {
    show-cursor
    IFS= read -rsn1 keypress
    disable-echo
    case "${keypress}" in
      $'\011') # TAB => Validate and move next. First case because the next one also captures it
        minlen=${cur_field[3]%/*}
        if [[ ${minlen} -le ${#cur_field[5]} ]]; then
          if [[ $((tab_index + 1)) -lt $len ]]; then
            tab_index=$((tab_index + 1))
          else
            tab_index=0
          fi
        else
          err_msg="This field does not match the minimum length of ${minlen}"
        fi
        ;;
      [[:alpha:]] | [[:digit:]] | [[:space:]] | [[:punct:]]) # Capture any input typed
        f_mode="${cur_field[1]}"
        f_type="${cur_field[2]}"
        maxlen=${cur_field[3]##*/}
        if [ "rw" = "${cur_field[4]}" ] && [[ ${#cur_field[5]} -lt maxlen ]]; then
          if __hhs_minput_validate "${f_type}" "${keypress}"; then
            cur_field[5]="${cur_field[5]}${keypress}"
            all_fields[$tab_index]="${cur_field[0]}:${cur_field[1]}:${cur_field[2]}:${cur_field[3]}:${cur_field[4]}:${cur_field[5]}"
          else
            err_msg="This field only accept ${f_type}s !"
          fi
        elif [ "r" = "${cur_field[4]}" ]; then
          err_msg="This field is read only !"
        fi
        ;;
      $'\177') # Backspace
        if [ "rw" = "${cur_field[4]}" ] && [[ ${#cur_field[5]} -ge 1 ]]; then
          # Delete the previous character
          cur_field[5]="${cur_field[5]::${#cur_field[5]}-1}"
          all_fields[$tab_index]="${cur_field[0]}:${cur_field[1]}:${cur_field[2]}:${cur_field[3]}:${cur_field[4]}:${cur_field[5]}"
        elif [ "r" = "${cur_field[4]}" ]; then
          err_msg="This field is read only !"
        fi
        ;;
      $'\033') # Handle escape '\e[nX' codes
        IFS= read -rsn2 -t 1 keypress
        case "${keypress}" in
          [A) # Cursor up
            if [[ $((tab_index - 1)) -ge 0 ]]; then
              tab_index=$((tab_index - 1))
            fi
            ;;
          [B) # Cursor down
            if [[ $((tab_index + 1)) -lt $len ]]; then
              tab_index=$((tab_index + 1))
            fi
            ;;
          *) # Escape pressed
            if [[ "${#keypress}" -eq 1 ]]; then
              break
            fi
            ;;
        esac
        ;;
      $'') # Validate & Save the form and exit
        # TODO validate form before submitting
        # minlen=${f_max_min_len%/*}
        # maxlen=${f_max_min_len##*/}
        echo -n '' > "${outfile}"
        for idx in ${!all_fields[*]}; do
          echo -n "${all_fields[$idx]%%:*}" | tr '[:lower:]' '[:upper:]' >> "${outfile}"
          echo "=${all_fields[$idx]##*:}" >> "${outfile}"
        done
        break
        ;;
      *)
        unset keypress
        ;;
    esac
    # } Navigation input
    re_render=1

  done
  # Restore exit position
  tput cup "${exit_pos%,*}" "${exit_pos#*,}"
  show-cursor
  enable-line-wrap
  enable-echo
  echo -e "\n${NC}"

  return 0
}
