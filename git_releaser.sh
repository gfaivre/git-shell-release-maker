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
readonly APPS_DIRNAME="${__dir}/apps"
readonly REPOSITORY_CACHE_DIR=${APPS_DIRNAME}/.cached-copy/${APP_NAME}
readonly RELEASE_PATH_DIR=${APPS_DIRNAME}/${APP_NAME}

# GIT variables
BRANCH=""
REVISION="HEAD"

#####################
# Utilities.        #
#####################

function display()
{
  local message="$1"
  printf "[\033[36mGIT Releaser\033[0m] \033[32m${message}\033[0m\n"
}

function display_error(){
  local error_message="${1}"
  printf "[\033[31mError\033[0m] \033[32m${error_message}\033[0m\n"
}

# Dump script usage syntax and options
function releaser_Usage(){
  echo "Usage: $0 [params] repository"
  echo "Params can be one or more of the following :"
  echo "    --version | -v     : Print out version number and exit"
  echo "    --branch  | -b     : Check out corresponding branch"
}

function setup(){
  # Creating workdir env
  mkdir -p ${APPS_DIRNAME}/${APP_NAME}
  mkdir -p ${REPOSITORY_CACHE_DIR}
  mkdir -p ${RELEASE_PATH_DIR}
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
  echo ${BRANCH}
  exit 1
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

function do_release(){
  local revision=$(get_revision)

  echo ${revision}
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
      shift # past argument
      shift # past value
    ;;
    -h | --help)
      releaser_Usage
      shift # past argument
      shift # past value
    ;;
    -b | --branch)
      if [ "${2:-}" = "" ]
      then
        display_error "You need to specified a branch name with --branch parameter"
        exit 1
      else
        BRANCH=${2}
      fi
      shift # past argument
    ;;
    -*)
      echo $1
      exit 1
    ;;
    *) # Unknown option
      releaser_Usage
      exit 0
    ;;
  esac
done

if [ $# -lt 1 ]
then
  releaser_Usage
else
  setup
  do_release
fi
