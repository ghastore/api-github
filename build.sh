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

  local dir="${API_DIR}/${API_ORG}"
  local f_org="${dir}/${API_ORG}.json"

  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  if [[ ! -f "${f_org}" ]] || [[ $( ${find} "${f_org}" -mmin ${TIME_MOD} -print ) ]]; then
    _gh "orgs/${API_ORG}" "${f_org}"
  fi

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: REPOSITORIES.
# -------------------------------------------------------------------------------------------------------------------- #

api_repos() {
  echo "--- [GITHUB] REPOSITORIES"
  _pushd "${d_src}" || exit 1

  local dir="${API_DIR}/${API_ORG}/repos"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local repos
  readarray -t repos < <( _gh_list "orgs/${API_ORG}/repos?type=public" ".[].name" )

  for repo in "${repos[@]}"; do
    local f_repo="${dir}/${repo}.json"
    local f_readme="${dir}/${repo}.readme.json"

    if [[ ! -f "${f_repo}" ]] || [[ $( ${find} "${f_repo}" -mmin ${TIME_MOD} -print ) ]]; then
      _gh "repos/${API_ORG}/${repo}" "${f_repo}"
    fi

    if [[ ! -f "${f_readme}" ]] || [[ $( ${find} "${f_readme}" -mmin ${TIME_MOD} -print ) ]]; then
      _gh "repos/${API_ORG}/${repo}/readme" "${f_readme}"
    fi
  done

  ${jq} -nc '$ARGS.positional' --args "${repos[@]}" > "${dir%/*}/${API_ORG}.repos.json"

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: USERS.
# -------------------------------------------------------------------------------------------------------------------- #

api_users() {
  echo "--- [GITHUB] USERS"
  _pushd "${d_src}" || exit 1

  local dir="${API_DIR}/${API_ORG}/users"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local users
  readarray -t users < <( _gh_list "orgs/${API_ORG}/public_members" ".[].login" )

  for user in "${users[@]}"; do
    local f_user="${dir}/${user}.json"

    if [[ ! -f "${f_user}" ]] || [[ $( ${find} "${f_user}" -mmin ${TIME_MOD} -print ) ]]; then
      _gh "users/${user}" "${f_user}"
    fi
  done

  ${jq} -nc '$ARGS.positional' --args "${users[@]}" > "${dir%/*}/${API_ORG}.users.json"

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
