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

# Vars.
TIME_MOD="+$(( 60*24 ))"

# Apps.
date="$( command -v date )"
find="$( command -v find )"
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

  local u_org="orgs/${API_OWNER}"
  local d_org="${API_DIR}/${API_OWNER}"
  local f_org="${d_org}/${API_OWNER}.json"

  [[ ! -d "${d_org}" ]] && _mkdir "${d_org}"

  # Org API.
  if [[ ! -f "${f_org}" ]] || [[ $( ${find} "${f_org}" -mmin ${TIME_MOD} -print ) ]]; then
    echo "Get API '${u_org}'..." && _gh "${u_org}" "${f_org}"
  else
    echo "File '${f_org}' is not changed!"
  fi

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: REPOSITORIES.
# -------------------------------------------------------------------------------------------------------------------- #

api_repos() {
  echo "--- [GITHUB] REPOSITORIES"
  _pushd "${d_src}" || exit 1

  local d_repos="${API_DIR}/${API_OWNER}/repos"
  [[ ! -d "${d_repos}" ]] && _mkdir "${d_repos}"

  local repos
  readarray -t repos < <( _gh_list "orgs/${API_OWNER}/repos?type=public" ".[].name" )

  for repo in "${repos[@]}"; do
    local u_repos="repos/${API_OWNER}/${repo}"
    local u_readme="repos/${API_OWNER}/${repo}/readme"
    local f_repo="${d_repos}/${repo}.json"
    local f_readme="${d_repos}/${repo}.readme.json"

    # Repos API.
    if [[ ! -f "${f_repo}" ]] || [[ $( ${find} "${f_repo}" -mmin ${TIME_MOD} -print ) ]]; then
      echo "Get API '${u_repos}'..." && _gh "${u_repos}" "${f_repo}"
    else
      echo "File '${f_repo}' is not changed!"
    fi

    # Readme API.
    if [[ ! -f "${f_readme}" ]] || [[ $( ${find} "${f_readme}" -mmin ${TIME_MOD} -print ) ]]; then
      echo "Get API '${u_readme}'..." && _gh "${u_readme}" "${f_readme}"
    else
      echo "File '${f_readme}' is not changed!"
    fi
  done

  ${jq} -nc '$ARGS.positional' --args "${repos[@]}" > "${d_repos%/*}/${API_OWNER}.repos.json"

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: USERS.
# -------------------------------------------------------------------------------------------------------------------- #

api_users() {
  echo "--- [GITHUB] USERS"
  _pushd "${d_src}" || exit 1

  local d_users="${API_DIR}/${API_OWNER}/users"
  [[ ! -d "${d_users}" ]] && _mkdir "${d_users}"

  local users
  readarray -t users < <( _gh_list "orgs/${API_OWNER}/public_members" ".[].login" )

  for user in "${users[@]}"; do
    local u_user="users/${user}"
    local u_gpg="${u_user}/gpg_keys"
    local f_user="${d_users}/${user}.json"
    local f_gpg="${d_users}/${user}.gpg.json"

    # Users API.
    if [[ ! -f "${f_user}" ]] || [[ $( ${find} "${f_user}" -mmin ${TIME_MOD} -print ) ]]; then
      echo "Get API '${u_user}'..." && _gh "${u_user}" "${f_user}"
    else
      echo "File '${f_user}' is not changed!"
    fi

    # GPG API.
    if [[ ! -f "${f_gpg}" ]] || [[ $( ${find} "${f_gpg}" -mmin ${TIME_MOD} -print ) ]]; then
      echo "Get API '${u_gpg}'..." && _gh "${u_gpg}" "${f_gpg}"
    else
      echo "File '${f_gpg}' is not changed!"
    fi
  done

  ${jq} -nc '$ARGS.positional' --args "${users[@]}" > "${d_users%/*}/${API_OWNER}.users.json"

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
