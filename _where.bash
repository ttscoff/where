#!/bin/bash
source $(dirname $BASH_SOURCE)/common.bash
# where 1.0.5 by Brett Terpstra 2015, WTF license <http://www.wtfpl.net/>

#### Description
# For people who spread bash functions and aliases across multiple sourced
# files and then can't track down where they defined them

#### Installation
#
## Option 1: Hook source
#
# This option will hook the Bash default `source` command and index shell
# scripts whenenver they're sourced from another file.
#
# Add the following to your .bash_profile before any
# source commands are run:
#
#   export WHERE_HOOK_SOURCE=true
#   source /path/to/_where.bash
#
#  If using this option, see the WHERE_EXPIRATION configuration option.
#
## Option 2:
# 1. Source _where.sh in your .bash_profile prior to sourcing other files
#
#     source /path/to/_where.bash
#
# 2. Add the following to the bottom of specific files to be indexed:
#
#     _where_from $BASH_SOURCE
#
# Indexing every file you source can slow down login, so option 2 may be ideal.
# You can add the necessary line to every file in a folder and subfolders
# using the _where_add function:
#
#   $ _where_add ~/scripts{,/**}/*.{,ba}sh
#
# Remove the lines using the _where_clean function:
#
#   $ _where_clean ~/scripts{,/**}/*.{,ba}sh
#
#### Usage
#
#   where function_name
#
# Once the database is built, you can use the `where` command to find your
# functions. Running `where` with no arguments will output a list of all
# registered plugins and aliases.
#
# Add an argument to filter for a specific function or alias. By default
# only exact matches will return. If an exact match is found, just the
# file path of the originating script will be returned.
#
## Options
#
#    -k   Show all functions and aliases containing filter text
#    -a   Show all functions and aliases fuzzy matched
#    -h   Show this screen
#    -v   Verbose output
#    -n   Suppress line number in paths
#    -E   Edit result
#
# The -k switch turns on "apropos" mode, which lets you find any function
# containing the filter string in its name.
#
# The -a switch takes "apropos" a step further, using the filter argument
# as a fuzzy search string. It will match any functions/arguments containing
# the characters in the search string in sequence, but they do not need
# to be contiguous.
#
# If -a is specified, -k is ignored in the arguments.
#
# -E causes $EDITOR to be opened with the path to the file containing
# the searched function. -E does not work with -k or -a.
#
## Aliases
#
# `where?` is equivalent to `where -k`
# `where*` is equivalent to `where -a`
#
#### Configuration
#
## Database location
#
# You can customize the location of the text file `where` uses with the
# environment variable $WHERE_FUNCTIONS_FROM_DB. Set it before sourcing
# the script in ~/.bash_profile:
#
#   export WHERE_FUNCTIONS_FROM_DB=/new/path/filename
#
## Source hook
#
# To enable `where` to automatically index any file sourced in your
# configuration, set the WHERE_HOOK_SOURCE variable to true before
# sourcing _where.bash in ~/.bash_profile:
#
#   export WHERE_HOOK_SOURCE=true
#
## Database refresh throttling
#
# Set an expiration threshhold on the database with WHERE_EXPIRATION.
# The threshhold is in seconds, where one day is 3600. If `where` is
# initialized within the thresshold since last update, it won't index
# the files again.
#
#   export WHERE_EXPIRATION=3600
#
#### End
DEBUG=false
## Initialization
# If no WHERE_FUNCTIONS_FROM_DB env var is set, use default
[[ -z $WHERE_FUNCTIONS_FROM_DB ]] && export WHERE_FUNCTIONS_FROM_DB="$HOME/.where_functions"

touch $WHERE_FUNCTIONS_FROM_DB

_debug() {
  $DEBUG && __color_out "%b_white%where: %purple%$*"
}

_where_updated() {
  awk '/^[0-9]+$/{print}' "$WHERE_FUNCTIONS_FROM_DB"
}

# Check the last index date, only update based on WHERE_EXPIRATION
_where_db_fresh() {
  if [[ ! -e $WHERE_FUNCTIONS_FROM_DB || $(( $(cat "$WHERE_FUNCTIONS_FROM_DB"|wc -l)<=1 )) == 1 || -z $WHERE_EXPIRATION || $WHERE_EXPIRATION == 0 ]]; then
    _debug "no database, no expiration set, or expiration 0"
    export WHERE_DB_EXPIRED=true
    return 1
  fi
  local last_update=$(_where_updated)
  if [[ $last_update == "" ]]; then
    _debug "No timestamp in index"
    export WHERE_DB_EXPIRED=true
    return 1
  fi

  _debug "last update: `date -r $last_update`"
  _debug "time since update: $(( $(date '+%s')-$last_update ))"
  if [ $(( $(date '+%s')-$last_update )) -ge $WHERE_EXPIRATION ]; then
    _debug "%red%Expired (threshhold $WHERE_EXPIRATION)"
    export WHERE_DB_EXPIRED=true
    return 1
  fi
  export WHERE_DB_EXPIRED=false
  _debug "%green%database fresh"
  return 0
}

_where_reset() {
  local dbtmp
  if [[ $1 == "hard" ]]; then
    __color_out "%b_white%where: %b_red%Clearing function index"
    echo -n > "$WHERE_FUNCTIONS_FROM_DB"
  else
    __color_out "%b_white%where: %b_red%Resetting function index"
    dbtmp=$(mktemp -t WHERE_DB.XXXXXX) || return
    trap "rm -f -- '$dbtmp'" RETURN
    awk '!/^[0-9]+$/{print}' "$WHERE_FUNCTIONS_FROM_DB" > "$dbtmp"
    mv -f "$dbtmp" "$WHERE_FUNCTIONS_FROM_DB"
    trap - RETURN
  fi
}

_where_set_update() {
  local dbtmp
  dbtmp=$(mktemp -t WHERE_DB.XXXXXX) || return
  trap "rm -f -- '$dbtmp'" RETURN
  date '+%s' > "$dbtmp"
  awk '!/^[0-9]+$/{print}' "$WHERE_FUNCTIONS_FROM_DB" >> "$dbtmp"
  mv -f "$dbtmp" "$WHERE_FUNCTIONS_FROM_DB"
  trap - RETURN
}

# If this is the first time _where has been sourced in this session, expire the db
_where_db_fresh || _where_reset

# Convert a string into a fuzzy-match regular expression for _where
# Separates each character and adds ".*" after, removing spaces
# @param 1: (Required) string to convert
_where_to_regex ()
{
    _regex_escape "$*" | sed -E 's/([[:alnum:]]) */\1[^:]*/g'
}

# "where" database function
# Parses for function and alias definitions to add to text list
# Existing definitions with same name are replaced
# Database file index format:
#   func_or_alias_name:(function|alias):path_to_source
# @param 1: (Required) single file path to parse and index
_where_from() {
  local needle dbtmp
  local srcfile=$1

  [[ ! -e $srcfile ]] && return 1
  touch $WHERE_FUNCTIONS_FROM_DB
  >&2 __color_out -n "\033[K%white%Indexing %red%$1...\r"
  # create a temp file and clean on return
  dbtmp=$(mktemp -t WHERE_DB.XXXXXX) || return
  trap "rm -f -- '$dbtmp'" RETURN

  IFS=$'\n' cat "$srcfile" | awk '/^(function )?[_[:alnum:]]+ *\(\)/{gsub(/(function | *\(.+)/,"");print $1":"NR}' | while read f
  do
    declare -a farr=( $(echo $f|sed -E 's/:/ /g') )

    needle=$(_regex_escape ${farr[0]})
    grep -vE "^$needle:" "$WHERE_FUNCTIONS_FROM_DB" > "$dbtmp"
    echo "${farr[0]}:function:$srcfile:${farr[1]}" >> "$dbtmp"
    sort -u "$dbtmp" -o "$WHERE_FUNCTIONS_FROM_DB"
  done

  IFS=$'\n' cat "$srcfile" | awk '/^alias/{gsub(/(^\s*alias |=.*$)/,"");print $1":"NR}' | while read f
  do
    declare -a farr=( $(echo $f|sed -E 's/:/ /g') )

    needle=$(_regex_escape ${farr[0]})
    grep -vE "^$needle:" "$WHERE_FUNCTIONS_FROM_DB" > "$dbtmp"
    echo "${farr[0]}:alias:$srcfile:${farr[1]}" >> "$dbtmp"
    sort -u "$dbtmp" -o "$WHERE_FUNCTIONS_FROM_DB"
  done

  rm -f -- "$dbtmp"
  trap - RETURN
  >&2 echo -ne "\033[K"
  _where_set_update
}

# Filter to ouput columnar "where" query results, in color if supported
# Takes input from STDIN, no arguments
_where_results_color() {
  if which tput > /dev/null 2>&1 && [[ $(tput -T$TERM colors) -ge 8 ]]; then
    cat |  awk -F ':' '{sub(/^/,"\033[33m",$1);sub(/^/,"\033[31m",$2);sub(/\/Users\/[^\/]*/,"~",$3);sub(/^/,"\033[1;37m",$3);print $1"|"$2"|"$3"\033[1;36m:"$4"\033[0m"}' | column -s '|' -t
  else
    cat | column -s ' ' -t
  fi
}

# Main "where" function for querying database
# @argument 1: (optional) string to filter results
# @option: [-k] apropos, any entry name containing exact filter string
# @option: [-a] fuzzy filter, any entry name containing characters from
#   filter string in sequence but not required to be contiguous
#   -a overrides -k
# @option: [-v] verbose output
# @option: [-n] suppress line numbers
# No filter string shows full index
# Filter string with no option (-k, -a) shows exact name matches only
where() {
  local needle cmd_type res res_array lnum
  local fuzzy=false
  local apropos=false
  local verbose=false
  local edit=false
  local linenumbers=true
    IFS='' read -r -d '' helpstring <<'ENDHELPSTRING'
where: Show where a function or alias is originally defined
Use -h for help
ENDHELPSTRING

  IFS='' read -r -d '' helpoptions <<'ENDOPTIONSHELP'
where: Show where a function or alias is originally defined
  %b_white%where [-kav] [function_name|search_pattern]
%yellow%Options:
  %b_white%-k   %yellow%Show all functions and aliases containing filter text
  %b_white%-a   %yellow%Show all functions and aliases fuzzy matched
  %b_white%-h   %yellow%Show this screen
  %b_white%-v   %yellow%Verbose output
  %b_white%-E   %yellow%Edit result
  %b_white%-n   %yellow%Suppress line number in paths

ENDOPTIONSHELP

  if [ $# == 0 ]; then
    awk '!/^[0-9]+$/{print}' "$WHERE_FUNCTIONS_FROM_DB" | _where_results_color
    # cat "$WHERE_FUNCTIONS_FROM_DB" | _where_results_color
    return 0
  fi

  DEBUG=false
  OPTIND=1
  while getopts "kahdvEn" opt; do
    case $opt in
      h) __color_out "$helpoptions"; return;;
      k) apropos=true ;;
      a) fuzzy=true ;;
      d) DEBUG=true ;;
      v) verbose=true ;;
      E) edit=true ;;
      n) linenumbers=false ;;
      *)
        __color_out "$helpstring" >&2
        return 1
    esac
  done
  shift $((OPTIND-1))

  if $fuzzy; then
    needle="^[^:]*$(_where_to_regex $1)[^:]*:"
  elif $apropos; then
    needle="^[^:]*$1[^:]*:"
  else
    cmd_type=$(builtin type -t $1)
    if [[ $cmd_type != "function" && $cmd_type != "alias" ]]; then
      _where_fallback $1
      return $?
    else
      needle=$1
    fi
  fi

  _debug "Searching for '$needle'"

  if $fuzzy || $apropos; then
    if [[ $(grep -Ec $needle $WHERE_FUNCTIONS_FROM_DB) > 0 ]]; then
      grep -E $needle $WHERE_FUNCTIONS_FROM_DB | _where_results_color
      return 0
    fi
  else
    if [[ $(grep -Ec "^$needle:" $WHERE_FUNCTIONS_FROM_DB) > 0 ]]; then
      res=$(grep -E "^$needle:" $WHERE_FUNCTIONS_FROM_DB)
      declare -a res_array=( $(echo $res|sed -E 's/:/ /g') )
      # __color_out "%yellow%${res_array[1]} %b_white%${res_array[0]} %yellow%defined in: %b_white%${res_array[2]}"
      lnum=""
      if $verbose; then
        if $linenumbers; then lnum=" on line ${res_array[3]}"; fi
        echo "${res_array[1]} ${res_array} is defined in ${res_array[2]}$lnum"
      else
        if $linenumbers; then lnum=":${res_array[3]}"; fi
        echo "${res_array[2]}$lnum"
      fi
      if [[ $edit == true && ! -z $EDITOR ]]; then
        if $linenumbers; then lnum=":${res_array[3]}"; fi
        $EDITOR "${res_array[2]}$lnum"
      fi
      return 0
    fi
  fi

  _where_fallback $1
}

_where_fallback() {
  local res pre
  local cmd_type=$(builtin type -t $1)
  if [[ $cmd_type == "" ]]; then
    __color_out "%red%No match found for %b_white%$1"
    return 1
  elif [[ $cmd_type == "function" ]]; then
    __color_out "%red%Function %b_white%$1 %red%not found in where's index"
    return 1
  elif [[ $cmd_type == "file" ]]; then
    pre="%yellow%File: %b_white%"
    res=$(builtin type -p $1 2> /dev/null)
  else
    pre="%yellow%Other: %b_white%"
    res=$(builtin type $1 2> /dev/null)
  fi

  if [[ $res != "" ]]; then
    __color_out "${pre}${res}"
  else
    return 1
  fi
}

# Util function to remove _where_from $BASH_SOURCE lines from specified files
# Example: _where_clean ~/scripts{,/**}/*.{,ba}sh
_where_clean() {
  for f in $@; do
    >&2 __color_out -n "%b_red%Cleaning %b_white%$f...\r"
    # safely create a temp file
    t=$(mktemp -t where_clean.XXXXXX)
    trap "rm -f -- '$t'" RETURN
    grep -v "^_where_from \$BASH_SOURCE" $f > $t
    mv -f "$t" "$f"
    trap - RETURN
  done
  >&2 echo -ne "\033[K"
}

# Util function to add lines to individual files to index them when sourced
# Can be used instead of hooking builtin source to only index given files
# Example: _where_add ~/scripts{,/**}/*.{,ba}sh
_where_add() {
  for f in $@; do
    _where_clean $f
    >&2 __color_out -n "%b_green%Initializing %b_white%$f...\r"
    echo -e "\n_where_from \$BASH_SOURCE" >> $f
  done
  >&2 echo -ne "\033[K"
}

# Aliases for apropos and fuzzy search
alias where?="where -k"
alias where*="where -a"

# hook source builtin to index source bash files
if [[ ${WHERE_HOOK_SOURCE:-false} == true ]]
then
  function source() {
    builtin source $@
    [[ ${WHERE_HOOK_SOURCE:-} == true && $WHERE_DB_EXPIRED == true ]] || return 0

    for f in $@; do
      if [[ $f =~ \.(ba)?sh$ && $(grep -cE "^_where_from \$BASH_SOURCE" $f) == 0 ]]; then
        for f in $@; do
          _where_from $f
        done
      fi
    done
  }
fi

# Add functions from self to index
_where_from $BASH_SOURCE
_where_from $(dirname $BASH_SOURCE)/common.bash
