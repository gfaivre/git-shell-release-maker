#!/bin/sh
#
#title              : git_releaser.sh
#description        : Clone/Mirror and/or update a git repository before making a release
#date               : 20171211
#usage              : git_releaser.sh app_name repository_url
#notes              : Git 1.9 or greater mandatory
#===================================================================

APP_NAME=$1
REPOSITORY_URL=$2

ROOT_DIR="$(dirname $(pwd))"
APPS_DIRNAME="${ROOT_DIR}/apps"
DEPLOY_BRANCH_NAME="quantum"
REPOSITORY_PATH=${APPS_DIRNAME}/${APP_NAME}/cached-copy
RELEASE_PATH=${APPS_DIRNAME}/${APP_NAME}/release

# Git
SHALLOW_CLONE=0
STRATEGY=${STRATEGY:-clone}

# Release configuration
BRANCH=${BRANCH:-master}
REMOTE=${REMOTE:-origin}
REVISION=${REVISION:-HEAD}

if [ $# -eq 0 ]; then
  echo "No arguments provided"
  echo "Usage:"
  echo "git_checkout.sh APP_NAME REPOSITORY_URL"
  exit 1
fi

if [ -z ${REPOSITORY_URL} ];
then
  echo "You should provide a repository URL" >&2
  exit 1
fi

function display(){
  local message="$1"
  printf "[\033[36mQuantum\033[0m] \033[32m${message}\033[0m\n"
}

function setup(){
  # Creating workdir env
  mkdir -p ${APPS_DIRNAME}/${APP_NAME}
  mkdir -p ${REPOSITORY_PATH}
  mkdir -p ${RELEASE_PATH}
}

function is_file_exists(){
  local fexists="$1"
  [[ -f "${fexists}" ]] && return 0 || return 1
}

function cleanup(){
  local target="$1"
  local verbose=$2
  local args=""

  args="-rf"

  # Wondering why "" ? See https://stackoverflow.com/a/2953673
  if [ "$verbose" = true ]
  then
    args="${args}v"
  fi

  $(find ${target} ! -path ${target} -print0 | xargs -I {} -0 rm ${args} "{}")
}

# Get revision by listing references in the remote repository
function fetch_revision(){
  revision=$(git ls-remote --quiet ${REPOSITORY_URL} ${BRANCH})
  echo ${revision}|cut -d " " -f 1
}

# Checkout a repository branch to a given revision
function checkout(){
  local remote="$1"
  local branch="$2"
  local revision="$3"
  local destination="$4"
  local args=""

  # Add an option for the branch name so :git_shallow_clone works with branches
  if [ "${revision}" == "${branch}" ]
  then
    args="${args} -b ${branch}"
  fi

  if [ "${remote}" != "origin" ]
  then
    args="${args} -o ${remote}"
  fi

  if [ ${SHALLOW_CLONE} -gt 0 ]
  then
    args="${args} --depth  ${SHALLOW_CLONE}"
  fi

  # Cloning repository (checkout to quantum branch by default to avoid mistakes)
  cd ${destination} && \
  $(git clone ${args} --no-single-branch ${REPOSITORY_URL} ${destination}) && \
    git checkout -b ${DEPLOY_BRANCH_NAME} ${revision}
}

function sync_repo(){
  local revision="$1"
  local destination="$2"

  cd ${destination}
  git fetch origin && git fetch --tags  origin && git reset  --hard ${revision}
  git clean -d -x -f
}

function mark(){
  local revision="$1"

  (echo ${revision} > ${RELEASE_PATH}/REVISION)
}

function clone_repo(){
  if [ ${SHALLOW_CLONE} -gt 0 ]
  then
    git clone --mirror --depth ${SHALLOW_CLONE} --no-single-branch ${REPOSITORY_URL} ${REPOSITORY_PATH}
  else
    git clone --mirror ${REPOSITORY_URL} ${REPOSITORY_PATH}
  fi
}

function update_mirror(){
  local branch="$1"

  cd ${REPOSITORY_PATH}
  # Update the origin URL if necessary.
  git remote set-url origin ${REPOSITORY_URL}

  # Note: Requires git version 1.9 or greater
  if [ ${SHALLOW_CLONE} -gt 0 ]
  then
    git fetch --depth ${SHALLOW_CLONE} origin ${branch}
  else
    git remote update --prune
  fi
}

function mirror(){
  local branch="$1"

  if ( is_file_exists "${REPOSITORY_PATH}/HEAD" )
    then
      display "Mirror already exists (Updating from branch: ${branch})"
      update_mirror ${branch}
    else
      echo "Mirror does not exists ... cloning"
      cleanup "${REPOSITORY_PATH}"
      clone_repo
  fi
}

function clone (){
  local branch="$1"

  # Switch from mirror strategy let's clean up ?
  if ( is_file_exists "${REPOSITORY_PATH}/HEAD" )
  then
    display "Cleaning up mirror repository ..."
    cleanup "${REPOSITORY_PATH}" true
  fi

  # We are checking if repository is empty before cloning.
  if [ "$(ls -A ${REPOSITORY_PATH})" ];
  then
    display "Repository already exists, updating ..."
    sync_repo ${REVISION} ${REPOSITORY_PATH}
  else
    display "Repository does not exists ... cloning"
    checkout ${REMOTE} ${branch} ${REVISION} ${REPOSITORY_PATH}
  fi
}

function do_release(){
  display "Running with ${STRATEGY} strategy"
  cleanup ${RELEASE_PATH}

  if [ "${STRATEGY}" == "mirror" ]
  then
    mirror ${BRANCH}
  elif [ "${STRATEGY}" == "clone" ]
  then
    clone ${BRANCH}
  else
    display "Unknown strategy ${STRATEGY}"
    exit 1
  fi

  display "Preparing archive from ${BRANCH}:${REVISION}"
  cd ${REPOSITORY_PATH} && \
    $(git archive ${REVISION} | tar -x -f - -C ${RELEASE_PATH})

  # We add a file with the hash of the current build release
  mark ${REVISION}
}

setup
do_release
