# Shared util for color output using templates
# Template format:
#     %colorname%: text following colored normal weight
#     %b% or %b_colorname%: bold foreground
#     %u% or %u_colorname%: underline foreground
#     %s% or %s_colorname%: bold foreground and background
#     %n% or %n_colorname%: return to normal weight
#     %reset%: reset foreground and background to default
#
#     %reset% is only used within a string, it will automatically
#     be sent after any output
# Color names (prefix bg to set background):
#     black
#     red
#     green
#     yellow
#     cyan
#     purple
#     blue
#     white
# @option: -n no newline
# @param 1: (Required) template string to process and output
__color_out () {
  local newline=""
  OPTIND=1
  while getopts "n" opt; do
    case $opt in
      n) newline="n";;
    esac
  done
  shift $((OPTIND-1))
  # color output variables
  if which tput > /dev/null 2>&1 && [[ $(tput -T$TERM colors) -ge 8 ]]; then
    local _c_n="\033[0m"
    local _c_b="\033[1m"
    local _c_u="\033[4m"
    local _c_s="\033[7m"
    local _c_black="\033[30m"
    local _c_red="\033[31m"
    local _c_green="\033[32m"
    local _c_yellow="\033[33m"
    local _c_cyan="\033[34m"
    local _c_purple="\033[35m"
    local _c_blue="\033[36m"
    local _c_white="\033[37m"
    local _c_bgblack="\033[40m"
    local _c_bgred="\033[41m"
    local _c_bggreen="\033[42m"
    local _c_bgyellow="\033[43m"
    local _c_bgcyan="\033[44m"
    local _c_bgpurple="\033[45m"
    local _c_bgblue="\033[46m"
    local _c_bgwhite="\033[47m"
    local _c_reset="\033[0m"
  fi
  local template_str="echo -e${newline} \"$(echo -en "$@" \
    | sed -E 's/%([busn])_/${_c_\1}%/g' \
    | sed -E 's/%(bg)?(b|u|s|n|black|red|green|yellow|cyan|purple|blue|white|reset)%/${_c_\1\2}/g')$_c_reset\""

  eval "$template_str"
}

# Shared util to return full path for single file, including symlink resolution
# @param 1: (Required) single file path to resolve
_resolvedpath () {
  local p resolved
  if [[ "${1}" == \~*/* || "${1}" == \~ || "${1}" == \~/* || "${1}" == \~/ ]]; then
    p="${HOME}${1:1:${#1}}"
  else
    p="${1}"
  fi
  resolved=$(/usr/bin/env python -c 'import os;print os.path.realpath("'"$p"'");')
  echo $resolved
}

# Shared util to return absolute path for single file
# @param 1: (Required) single file path to resolve
_fullpath () {
  echo "$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
}

# Shared util function to escape a string for a regular expression
# Backslashes $ ^ . * ? () {} []
# @param 1: (Required) string to escape
_regex_escape ()
{
  echo -n "$@" | sed -E 's/([$^*?().{}]|\[|\])/\\\1/g'
}
