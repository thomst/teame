#!/bin/bash

USAGE="description:
    Clone or pull gitea repositories.

usage:
    tea-me.sh -h
    tea-me.sh [-l][-d DIR][-u LOGIN][-p COUNT] PATTERN

Get or update repositories from gitea.

actions:
    -l              list repositories
    -g              clone or pull repositories
    -c              clone repositories (that does not exist in cwd)
    -p              pull repositories (that exists in cwd)
    -s              print status of repositories
    -h              print help-message

options:
    -d [DIR]        working directory (default: current working directory)
    -u [LOGIN]      tea login (default: current unix user)
    -C [COUNT]      count of parallel processes (default: 8)
"

while getopts lgcpsd:u:C:h opt
do
    case $opt in
        l)  LIST_REPO=true;;
        g)  CLONE_OR_PULL_REPO=true;;
        c)  CLONE_REPO=true;;
        p)  PULL_REPO=true;;
        s)  GET_REPO_STATUS=true;;
        d)  CWD=$OPTARG;;
        u)  LOGIN=$OPTARG;;
        C)  PROCESS_POOL=$OPTARG;;
        h)  echo "$USAGE"; exit 0;;
        \?) echo "$USAGE"; exit 1;;
        :)  echo "$USAGE"; exit 1;;
    esac
done


#-------------------------------------------------------------------------------
# Set defaults for our runtime parameters.
#-------------------------------------------------------------------------------
PATTERN="${*:$OPTIND:1}"
CWD="${CWD:-"$(pwd)"}"
LOGIN="${LOGIN:-"$(id --user --name)"}"
PROCESS_POOL="${PROCESS_POOL:-8}"

#-------------------------------------------------------------------------------
# Set some useful global variables.
#-------------------------------------------------------------------------------
RTE_PIDS=()
MSG_ERROR="\r\e[31m[ERROR]\e[0m"
MSG_SUCCESS="\r\e[32m[SUCCESS]\e[0m"
MSG_INFO="\r\e[36m[INFO]\e[0m"
MSG_PULLED="\e[33m[PULLED]\e[0m"
MSG_CLONED="\e[33m[CLONED]\e[0m"
MSG_STATUS="\e[33m[STATUS]\e[0m"
MSG_CLEAN="\e[33m[CLEAN]\e[0m"


# FUNCTION ---------------------------------------------------------------------
# NAME:         get_list_of_repositories
# DESCRIPTION:  Retrieve a list of repository names and ssh adresses filtered by
#               a pattern from the gitea api via tea.
# PARAMETER 1:  [str] search pattern
# OUTPUT:       list of repository name and address seperated by a whitespace.
# ------------------------------------------------------------------------------
function get_list_of_repositories {
    pattern=$1
    repos=()
    index=0
    while true; do
        index=$((index+1))
        mapfile -t page < <(tea repos search --login="$LOGIN" --page=$index --output=simple --fields=name,ssh "$pattern")
        if [ -n "${page[*]}" ]; then
            repos+=("${page[@]}")
        else
            break
        fi
    done
    if [ -n "${repos[*]}" ]; then
        (IFS=$'\n'; echo "${repos[*]}")
    fi
}


# FUNCTION ---------------------------------------------------------------------
# NAME:         pull_repository
# DESCRIPTION:  Update a repository found in the current working directory by
#               pulling from the remote repository.
# PARAMETER 1:  [str] repository name
# OUTPUT:       Print informations about what has been done.
# ------------------------------------------------------------------------------
function pull_repository {
    name="$1"
    if [ ! -d "$CWD/$name/.git" ]; then
        echo -e "${MSG_INFO}${MSG_PULLED}[$name] missing repository"
        return
    fi
    pushd "$CWD/$name" > /dev/null || exit
    if output="$(git pull 2>&1)"; then
        echo -e "${MSG_SUCCESS}${MSG_PULLED} $name"
    else
        echo -e "${MSG_ERROR}${MSG_PULLED} $name"
        echo "$output"
    fi
    popd > /dev/null || exit
}


# FUNCTION ---------------------------------------------------------------------
# NAME:         clone_repository
# DESCRIPTION:  Clone a repository into the current working directory.
# PARAMETER 1:  [str] repository name
# PARAMETER 2:  [str] repository ssh address
# OUTPUT:       Print informations about what has been done.
# ------------------------------------------------------------------------------
function clone_repository {
    name="$1"
    ssh_address="$2"
    if [ -d "$CWD/$name/.git" ]; then
        echo -e "${MSG_INFO}${MSG_CLONED}[$name] repository already exists"
        return
    fi
    pushd "$CWD" > /dev/null || exit
    if output="$(git clone "$ssh_address" 2>&1)"; then
        echo -e "${MSG_SUCCESS}${MSG_CLONED} $name"
    else
        echo -e "${MSG_ERROR}${MSG_CLONED} $name"
        echo "$output"
    fi
    popd > /dev/null || exit
}


# FUNCTION ---------------------------------------------------------------------
# NAME:         get_repository_status
# DESCRIPTION:  Print repository status in machine readable format.
# PARAMETER 1:  [str] repository name
# OUTPUT:       Print informations about what has been done.
# ------------------------------------------------------------------------------
function get_repository_status {
    name="$1"
    if [ ! -d "$CWD/$name/.git" ]; then
        echo -e "${MSG_ERROR}${MSG_STATUS}[$name] missing repository"
        return
    fi
    pushd "$CWD/$name" > /dev/null || exit
    if output="$(git status --porcelain 2>&1)"; then
        if [ -n "$output" ]; then
            echo -e "${MSG_SUCCESS}${MSG_STATUS} $name"
            echo "$output"
        else
            echo -e "${MSG_SUCCESS}${MSG_CLEAN} $name"
        fi
    else
        echo -e "${MSG_ERROR}${MSG_STATUS} $name"
        echo "$output"
    fi
    popd > /dev/null || exit
}


# FUNCTION ---------------------------------------------------------------------
# NAME:         clone_or_pull_repository
# DESCRIPTION:  Call pull_repository or clone_repository depending on if the
#               repository already exists in the current working directory or
#               not.
# PARAMETER 1:  [str] repository name
# PARAMETER 2:  [str] repository ssh address
# ------------------------------------------------------------------------------
function clone_or_pull_repository {
    name="$1"
    ssh_address="$2"
    if [ -d "$CWD/$name/.git" ]; then
        pull_repository "$name"
    else
        clone_repository "$name" "$ssh_address"
    fi
}


# FUNCTION ---------------------------------------------------------------------
# NAME:         process_repositories
# DESCRIPTION:  Reading a list of repository name and ssh address pairs from
#               stdin and processing this list line by line in parallelized
#               background processes.
# OUTPUT:       Print the output of the action that was performed for each
#               repository.
# ------------------------------------------------------------------------------
function process_repositories {
    while [ -z "$RTE_LOOP_STOP" ] && read -r line; do
        name="${line% *}"
        ssh_address="${line#* }"

        #-----------------------------------------------------------------------
        # Process repositories within a background process for parallelization.
        #-----------------------------------------------------------------------
        (
            if [ -n "$CLONE_OR_PULL_REPO" ]; then
                output="$(clone_or_pull_repository "$name" "$ssh_address" 2>&1)"
            elif [ -n "$CLONE_REPO" ]; then
                output="$(clone_repository "$name" "$ssh_address" 2>&1)"
            elif [ -n "$PULL_REPO" ]; then
                output="$(pull_repository "$name" "$ssh_address" 2>&1)"
            elif [ -n "$GET_REPO_STATUS" ]; then
                output="$(get_repository_status "$name"  2>&1)"
            fi
            echo -e "$output"
        ) &

        #-----------------------------------------------------------------------
        # Save the process ids within a variable and setup a trap command.
        #-----------------------------------------------------------------------
        RTE_PIDS+=( $! )
        trap 'RTE_LOOP_STOP=true; kill -s TERM ${RTE_PIDS[*]} 2> /dev/null' SIGINT

        #-----------------------------------------------------------------------
        # Wait till there are less than PROCESS_POOL processes running.
        #-----------------------------------------------------------------------
        while (( "$(ps --no-headers --format pid -p "${RTE_PIDS[*]}" | wc -l)" >= "$PROCESS_POOL" )); do
            sleep 0.2
        done

        #-----------------------------------------------------------------------
        # Give the processes a little space.
        #-----------------------------------------------------------------------
        sleep 0.2

    done < "/dev/stdin"

    #---------------------------------------------------------------------------
    # Wait for background-processes.
    #---------------------------------------------------------------------------
    [[ -n "${RTE_PIDS[*]}" ]] && wait ${RTE_PIDS[*]}
}


#-------------------------------------------------------------------------------
# Run teame.
#-------------------------------------------------------------------------------
if [ -n "$LIST_REPO" ]; then
    get_list_of_repositories "$PATTERN" | cut --fields=1 --delimiter=' '
elif [ -n "$CLONE_REPO" ] || [ -n "$PULL_REPO" ] || [ -n "$CLONE_OR_PULL_REPO" ] || [ -n "$GET_REPO_STATUS" ]; then
    get_list_of_repositories "$PATTERN" | process_repositories
fi
