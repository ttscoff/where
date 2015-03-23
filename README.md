# where 

Brett Terpstra 2015, WTF license <http://wtflicense.com/>

## Description

For people who spread bash functions and aliases across multiple sourced
files and then can't track down where they defined them

## Installation

Place both _where.bash and common.bash in the same folder in your $PATH.

### Option 1: Hook `source`

This option will hook the Bash default `source` command and index shell scripts whenenver they're sourced from another file. 

Add the following to your .bash_profile before any source commands are run:

    export WHERE_HOOK_SOURCE=true
    export WHERE_EXPIRATION=86400 # once a day
    source /path/to/_where.bash

If you choose this option, see **Database refresh throttling** below.

### Option 2: Curated indexing

1. Source _where.sh in your .bash_profile prior to sourcing other files

        source /path/to/_where.bash

2. Add the following to the bottom of specific files to be indexed:

        _where_from $BASH_SOURCE

Indexing every file you source can slow down login, so option 2 may be ideal.

You can add the necessary line to every file in a folder and subfolders
using the `_where_add` function:

    $ _where_add ~/scripts{,/**}/*.{,ba}sh

Remove the lines using the _where_clean function:

    $ _where_clean ~/scripts{,/**}/*.{,ba}sh

## Usage

    where [-kav] [function_name|search_pattern]

Once the database is built, you can use the `where` command to find your
functions. Running `where` with no arguments will output a list of all
registered plugins and aliases.

Add an argument to filter for a specific function or alias. By default
only exact matches will return. If an exact match is found, just the
file path of the originating script will be returned.

### Options

    -k   Show all functions and aliases containing filter text
    -a   Show all functions and aliases fuzzy matched
    -v   Verbose output
    -n   Suppress line number in paths
    -E   Edit result
    -h   Show this screen

The -k switch turns on "apropos" mode, which lets you find any function
containing the filter string in its name.

The -a switch takes "apropos" a step further, using the filter argument
as a fuzzy search string. It will match any functions/arguments containing
the characters in the search string in sequence, but they do not need
to be contiguous.

If -a is specified, -k is ignored in the arguments.

-E causes $EDITOR to be opened with the path to the file containing
the searched function. -E does not work with -k or -a.

### Aliases

`where?` is equivalent to `where -k`
`where*` is equivalent to `where -a`

## Configuration

### Database location

You can customize the location of the text file `where` uses with the
environment variable `WHERE_FUNCTIONS_FROM_DB`. Set it before sourcing
the script in `~/.bash_profile`:

    export WHERE_FUNCTIONS_FROM_DB=/new/path/filename

### Source hook

To enable `where` to automatically index any file sourced in your
configuration, set the `WHERE_HOOK_SOURCE` variable to true before
sourcing `_where.bash` in `~/.bash_profile`:

    export WHERE_HOOK_SOURCE=true

### Database refresh throttling

Set an expiration threshold on the database with `WHERE_EXPIRATION`.
The threshold is in seconds, where one hour is 3600. If `where` is
initialized within the threshold since last update, it won't index
the files again.

    export WHERE_EXPIRATION=3600

You can force a database refresh with `_where_reset` on the command line. This will clear your database and set an update marker for the current time.
