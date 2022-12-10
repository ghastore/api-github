#!/bin/bash -e

# -------------------------------------------------------------------------------------------------------------------- #
# CONFIGURATION.
# -------------------------------------------------------------------------------------------------------------------- #

# Action.
GIT_REPO="${1}"
GIT_USER="${2}"
GIT_EMAIL="${3}"
GIT_TOKEN="${4}"
API_DIR="${5}"
API_OWNER="${6}"
API_TOKEN="${7}"

# Apps.
date="$( command -v date )"
gh="$( command -v gh )"
git="$( command -v git )"
jq="$( command -v jq )"
mkdir="$( command -v mkdir )"

# Dirs.
d_src="/root/git/repo"

# Environment.
export GH_TOKEN="${API_TOKEN}"

# Git.
${git} config --global user.name "${GIT_USER}"
${git} config --global user.email "${GIT_EMAIL}"
${git} config --global init.defaultBranch 'main'

# -------------------------------------------------------------------------------------------------------------------- #
# INITIALIZATION.
# -------------------------------------------------------------------------------------------------------------------- #

init() {
  ts="$( _timestamp )"
  clone \
    && api_org \
    && api_org_repos \
    && api_org_users \
    && push
}

# -------------------------------------------------------------------------------------------------------------------- #
# GIT: CLONE REPOSITORY.
# -------------------------------------------------------------------------------------------------------------------- #

clone() {
  echo "--- [GIT] CLONE: ${GIT_REPO#https://}"

  local src="https://${GIT_USER}:${GIT_TOKEN}@${GIT_REPO#https://}"
  ${git} clone "${src}" "${d_src}"

  echo "--- [GIT] LIST: '${d_src}'"
  ls -1 "${d_src}"
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: ORGANIZATION.
# -------------------------------------------------------------------------------------------------------------------- #

api_org() {
  echo "--- [GITHUB] ORGANIZATION"
  _pushd "${d_src}" || exit 1

  local dir="${API_DIR}/${API_OWNER}"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local api="orgs/${API_OWNER}"
  echo "Get '${api}'..." && _gh "${api}" "${dir}/${API_OWNER}.json"

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: ORGANIZATION REPOSITORIES.
# -------------------------------------------------------------------------------------------------------------------- #

api_org_repos() {
  echo "--- [GITHUB] REPOSITORIES"
  _pushd "${d_src}" || exit 1

  local dir="${API_DIR}/${API_OWNER}/repos"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local repos
  readarray -t repos < <( _gh_list "orgs/${API_OWNER}/repos?type=public" ".[].name" )

  for repo in "${repos[@]}"; do
    local api="repos/${API_OWNER}/${repo}"
    echo "Get '${api}'..." && _gh "${api}" "${dir}/${repo}.json"
    echo "Get '${api}/readme'..." && _gh "${api}/readme" "${dir}/${repo}.readme.json"
  done

  ${jq} -nc '$ARGS.positional' --args "${repos[@]}" > "${dir%/*}/${API_OWNER}.repos.json"

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: ORGANIZATION USERS.
# -------------------------------------------------------------------------------------------------------------------- #

api_org_users() {
  echo "--- [GITHUB] USERS"
  _pushd "${d_src}" || exit 1

  local dir="${API_DIR}/${API_OWNER}/users"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local users
  readarray -t users < <( _gh_list "orgs/${API_OWNER}/public_members" ".[].login" )

  for user in "${users[@]}"; do
    local api="users/${user}"
    echo "Get '${api}'..." && _gh "${api}" "${dir}/${user}.json"
    echo "Get '${api}/gpg_keys'..." && _gh "${api}/gpg_keys" "${dir}/${user}.gpg.json"
  done

  ${jq} -nc '$ARGS.positional' --args "${users[@]}" > "${dir%/*}/${API_OWNER}.users.json"

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# GIT: PUSH API TO API STORE REPOSITORY.
# -------------------------------------------------------------------------------------------------------------------- #

push() {
  echo "--- [GIT] PUSH: '${d_src}' -> '${GIT_REPO#https://}'"
  _pushd "${d_src}" || exit 1

  # Commit build files & push.
  echo "Commit build files & push..."
  ${git} add . \
    && ${git} commit -a -m "API: ${ts}" \
    && ${git} push

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# ------------------------------------------------< COMMON FUNCTIONS >------------------------------------------------ #
# -------------------------------------------------------------------------------------------------------------------- #

# Pushd.
_pushd() {
  command pushd "$@" > /dev/null || exit 1
}

# Popd.
_popd() {
  command popd > /dev/null || exit 1
}

# Timestamp.
_timestamp() {
  ${date} -u '+%Y-%m-%d %T'
}

# Make directory.
_mkdir() {
  ${mkdir} -p "${1}"
}

# GH API: Get list items.
_gh_list() {
  ${gh} api --paginate "${1}" -q "${2}" | sort
}

# GH API: Download.
_gh() {
  ${gh} api "${1}" > "${2}"
}

# -------------------------------------------------------------------------------------------------------------------- #
# -------------------------------------------------< INIT FUNCTIONS >------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

init "$@"; exit 0
