#!/usr/bin/env bash
#
# GIT releaser version 1.0.x
# Author: Guewen FAIVRE (guewen.faivre@elao.com)
#
# Utility to self-creating a project release
# The resulting directory hold the repository content at the given branch/revision
#
# Version history :
# - 1.0 : Initial public release
#
# This software is released under the terms of the GNU GPL version 2 and above
# Please read the license at http://www.gnu.org/copyleft/gpl.html
#
#=====================================================================================

# Handle errors properly
set -o errexit
# Get pipelines exit codes (The exit status of the last command that threw a non-zero exit code is returned.)
set -o pipefail
# Force declaration of ALL variables
set -o nounset
# Debug (commented by default)
#set -o xtrace

######################
# Variables          #
######################

# Magic variables
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
__parent="$(cd "$(dirname "${__dir}")" && pwd)"

# Variables
VERSION="1.0"

APP_NAME=${APP_NAME:-deploy}
STRATEGY="clone"

readonly APPS_DIRNAME="${__dir}/apps"
readonly REPOSITORIES_CACHE_DIR=${APPS_DIRNAME}/.cached-copy
readonly RELEASE_PATH_DIR=${APPS_DIRNAME}

# GIT variables
REPOSITORY=""
BRANCH="master"
REVISION="HEAD"
SHALLOW_CLONE=false

#####################
# Utilities.        #
#####################

function is_file_exists(){
  local fexists="$1"
  [[ -f "${fexists}" ]] && return 0 || return 1
}

function cleanup(){
  local target="$1"
  local verbose=${2:-false}
  local args=""

  args="-rf"

  # Wondering why "" ? See https://stackoverflow.com/a/2953673
  if [ "$verbose" = true ]
  then
    args="${args}v"
  fi

  $(find ${target} ! -path ${target} -print0 | xargs -I {} -0 rm ${args} "{}")
}

function display()
{
  local message="$1"
  printf "[\033[36mInfo\033[0m] \033[32m${message}\033[0m\n"
}

function display_error(){
  local error_message="${1}"
  printf "[\033[31mError\033[0m] \033[32m${error_message}\033[0m\n"
}

# Dump script usage syntax and options
function releaser_Usage(){
  printf "[\033[36mUsage\033[0m]: \033[32m$0 [params] repository\033\n"
  printf "\033[32mParams can be one or more of the following :\032\n"
  printf "\033[36m    --version   | -v\033[0m  : Print out version number and exit\n"
  printf "\033[36m    --name      | -n\033[0m  : Specify the name of the release and checkout folders\n"
  printf "\033[36m    --branch    | -b\033[0m  : Check out corresponding branch\n"
  printf "\033[36m    --strategy  | -s\033[0m  : Change the way we create the local repository (clone or mirror, default is clone)\n"
  printf "\033[36m    --revision  | -r\033[0m  : Specify a revision to release\n"
  printf "\033[36m    --shallow   | -sh\033[0m : Create a shallow clone with a history truncated to the specified number of commits.\n"
}

function setup(){
  # Creating workdir env
  mkdir -p ${APPS_DIRNAME}/${APP_NAME}
  mkdir -p ${REPOSITORIES_CACHE_DIR}/${APP_NAME}
  mkdir -p ${RELEASE_PATH_DIR}/${APP_NAME}
}

function is_valid_hash(){
  local commit_hash="${1}"

  if [[ "${commit_hash}" =~ ^[0-9a-f]{40}$ ]]
  then
    return 0
  else
    return 1
  fi
}

# Getting the actual commit id, in case we were passed a tag
# or partial sha or something - it will return the sha if you pass a sha, too
function get_revision(){
  local revision=""

  if (is_valid_hash ${REVISION})
    then
    echo ${REVISION}
    return 0
  fi

  # Ok we propably got a branch / tag name, let's find the hash
  revision=$(git ls-remote --quiet ${REPOSITORY} ${BRANCH})
  revision=$(echo ${revision}|cut -d " " -f 1)

  if (is_valid_hash ${revision})
    then
    echo ${revision}
    return 0
  else
    return 1
  fi
}

function mark(){
  (echo ${REVISION} > ${RELEASE_PATH_DIR}/${APP_NAME}/REVISION)
}

# Sync an existing repository with remote.
function sync_repo(){
  local revision="$1"
  local destination="$2"

  cd ${destination}
  git fetch origin && git fetch --tags  origin && git reset  --hard ${revision}
  git clean -d -x -f
}

# Checkout a repository branch to a given revision
function checkout(){
  local args=""
  local remote=${remote:-origin}

  # Add an option for the branch name so :git_shallow_clone works with branches
  if [ "${REVISION}" == "${BRANCH}" ]
  then
    args="${args} -b ${BRANCH}"
  fi

  if [ "${remote}" != "origin" ]
  then
    args="${args} -o ${remote}"
  fi

  if [ "${SHALLOW_CLONE}" != false ]
  then
    args="${args} --depth  ${SHALLOW_CLONE}"
  fi

  $(git clone ${args} --no-single-branch ${REPOSITORY} ${REPOSITORIES_CACHE_DIR}/${APP_NAME})
}

# Clones a repository or update it
function clone (){

  # Switch from mirror strategy let's clean up ?
  if ( is_file_exists "${REPOSITORIES_CACHE_DIR}/${APP_NAME}/HEAD" )
    then
    display "Cleaning up mirror repository ..."
    cleanup "${REPOSITORIES_CACHE_DIR}/${APP_NAME}" true
  fi

  # We are checking if repository is empty before cloning.
  if [ "$(ls -A ${REPOSITORIES_CACHE_DIR}/${APP_NAME})" ];
    then
    display "Repository already exists, updating ..."
    sync_repo ${REVISION} ${REPOSITORIES_CACHE_DIR}/${APP_NAME}
  else
    display "Repository does not exists ... cloning"
    checkout
  fi
}

# Set up a mirror of the source repository
function mirror_clone(){

  if [ "${SHALLOW_CLONE}" = false ]
    then
    git clone --mirror ${REPOSITORY} ${REPOSITORIES_CACHE_DIR}/${APP_NAME}
  else
    git clone --mirror --depth ${SHALLOW_CLONE} --no-single-branch ${REPOSITORY} ${REPOSITORIES_CACHE_DIR}/${APP_NAME}
  fi
}

function update_mirror(){
  cd ${REPOSITORIES_CACHE_DIR}/${APP_NAME}
  # Update the origin URL if necessary.
  git remote set-url origin ${REPOSITORY}

  # Note: Requires git version 1.9 or greater
  if [ "${SHALLOW_CLONE}" = false ]
    then
    git remote update --prune
  else
    git fetch --depth ${SHALLOW_CLONE} origin ${BRANCH}
  fi
}

# Update or create a mirror repository (bare).
function mirror(){
  if ( is_file_exists "${REPOSITORIES_CACHE_DIR}//${APP_NAME}/HEAD" )
    then
      display "Mirror already exists (Updating from branch: ${BRANCH})"
      update_mirror ${BRANCH}
    else
      echo "Mirror does not exists ... cloning"
      cleanup "${REPOSITORIES_CACHE_DIR}/${APP_NAME}"
      mirror_clone
  fi
}

# Building the release
function do_release(){
  REVISION=$(get_revision)

  if [ -z ${REVISION} ]
    then
    display_error "Unable to find or resolve revision on repository '${REPOSITORY}'."
    exit 1
  fi

  display "Running with ${STRATEGY} strategy"
  cleanup ${RELEASE_PATH_DIR}/${APP_NAME}

  if [ "${STRATEGY}" == "mirror" ]
    then
    mirror
  elif [ "${STRATEGY}" == "clone" ]
    then
    clone
  else
    display "Unknown strategy ${STRATEGY}"
    exit 1
  fi

  display "Preparing archive from ${BRANCH}:${REVISION}"
  cd ${REPOSITORIES_CACHE_DIR}/${APP_NAME} && \
    $(git archive ${REVISION} | tar -x -f - -C ${RELEASE_PATH_DIR}/${APP_NAME})

  # We add a file with the hash of the current build release
  mark ${REVISION}
}

###################
# Options         #
###################

while [[ $# -gt 0 ]]
do
  key="$1"

  case $key in
    -v|--version)
      display "Git releaser version ${VERSION}"
      shift 2
    ;;
    -h | --help)
      releaser_Usage
      shift 2
    ;;
    -n | --name)
      APP_NAME=${2}
      shift 2
    ;;
    -s | --strategy)
      STRATEGY=${2}
      shift 2
    ;;
    -r | --revision)
      REVISION=${2}
      shift 2
    ;;
    -sh | --shallow)
      SHALLOW_CLONE=${2}
      shift 2
    ;;
    -b | --branch)
      if [ "${2:-}" = "" ]
      then
        display_error "You need to specified a branch name."
        exit 1
      else
        BRANCH=${2}
      fi
      shift 2
    ;;
    -*)
      display_error "Unrecognized parameter ${1}"
      exit 1
    ;;
    *)
      break
    ;;
  esac
done

if [ $# -lt 1 ]
  then
  releaser_Usage
  exit 1
else
  REPOSITORY="${1}"
fi

setup
if (do_release)
  then
  display "Release build successfully"
fi
