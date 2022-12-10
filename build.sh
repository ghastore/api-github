#!/bin/bash -e

# -------------------------------------------------------------------------------------------------------------------- #
# CONFIGURATION.
# -------------------------------------------------------------------------------------------------------------------- #

# Vars.
GIT_REPO="${1}"
GIT_USER="${2}"
GIT_EMAIL="${3}"
GIT_TOKEN="${4}"
API_DIR="${5}"
API_ORG="${6}"
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
    && api_repos \
    && api_users \
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

  local dir; dir="${API_DIR}/${API_ORG}"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  _gh "orgs/${API_ORG}" "${dir}/${API_ORG}.json"
  _gh "orgs/${API_ORG}/public_members" "${dir}/${API_ORG}.members.json"

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: REPOSITORIES.
# -------------------------------------------------------------------------------------------------------------------- #

api_repos() {
  echo "--- [GITHUB] REPOSITORIES"
  _pushd "${d_src}" || exit 1

  local dir; dir="${API_DIR}/${API_ORG}/repos"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local repos
  readarray -t repos < <( _gh_list "orgs/${API_ORG}/repos" ".[].name" )

  for repo in "${repos[@]}"; do
    _gh "repos/${API_ORG}/${repo}" "${dir}/${repo}.json"
    _gh "repos/${API_ORG}/${repo}/readme" "${dir}/${repo}.readme.json"
  done

  ${jq} -nc '$ARGS.positional' --args "${repos[@]}" > "${dir}/_all.json"

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: USERS.
# -------------------------------------------------------------------------------------------------------------------- #

api_users() {
  echo "--- [GITHUB] USERS"
  _pushd "${d_src}" || exit 1

  local dir; dir="${API_DIR}/${API_ORG}/users"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local users
  readarray -t users < <( _gh_list "orgs/${API_ORG}/public_members" ".[].login" )

  for user in "${users[@]}"; do
    _gh "users/${user}" "${dir}/${user}.json"
  done

  ${jq} -nc '$ARGS.positional' --args "${users[@]}" > "${dir}/_all.json"

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
