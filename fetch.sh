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
API_TYPE="${6}"
API_OWNER="${7}"
API_TOKEN="${8}"

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
  clone
  _gh_rate

  case "${API_TYPE}" in
    'orgs')
      gh_owner && gh_repos && gh_events && gh_org_members && gh_org_collaborators
      ;;
    'users')
      gh_owner && gh_repos && gh_events
      ;;
    *)
      echo "[ERROR] UNKNOWN API TYPE!"
      exit 1
      ;;
  esac

  _gh_rate
  push
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
# API: OWNER.
# -------------------------------------------------------------------------------------------------------------------- #

gh_owner() {
  echo "--- [GITHUB] ${API_OWNER^^} / INFO"
  _pushd "${d_src}" || exit 1

  local dir="${API_DIR}/${API_TYPE}/${API_OWNER}"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local api="${API_TYPE}/${API_OWNER}"
  echo "Get '${api}'..." && _gh_file "${api}" "${dir}/info.json"

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: REPOSITORIES.
# -------------------------------------------------------------------------------------------------------------------- #

gh_repos() {
  echo "--- [GITHUB] ${API_OWNER^^} / REPOSITORIES"
  _pushd "${d_src}" || exit 1

  local dir="${API_DIR}/${API_TYPE}/${API_OWNER}/repos"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local url
  case "${API_TYPE}" in
    'orgs')
      url="${API_TYPE}/${API_OWNER}/repos?type=public"
      ;;
    'users')
      url="${API_TYPE}/${API_OWNER}/repos"
      ;;
    *)
      echo "[ERROR] UNKNOWN API TYPE!"
      exit 1
      ;;
  esac

  local repos
  readarray -t repos < <( _gh_list "${url}" ".[].name" )

  for repo in "${repos[@]}"; do
    local api_repo="repos/${API_OWNER}/${repo}"
    local dir_repo="${dir}/${repo}"
    [[ ! -d "${dir_repo}" ]] && _mkdir "${dir_repo}"
    echo "Get '${api_repo}'..." && _gh_file "${api_repo}" "${dir_repo}/info.json"
    echo "Get '${api_repo}/readme'..." && _gh_file "${api_repo}/readme" "${dir_repo}/readme.json"
  done

  ${jq} -nc '$ARGS.positional' --args "${repos[@]}" > "${dir%/*}/repos.json"

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: EVENTS.
# -------------------------------------------------------------------------------------------------------------------- #

gh_events() {
  echo "--- [GITHUB] ${API_OWNER^^} / EVENTS"
  _pushd "${d_src}" || exit 1

  local dir="${API_DIR}/${API_TYPE}/${API_OWNER}"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local url
  case "${API_TYPE}" in
    'orgs')
      url="${API_TYPE}/${API_OWNER}/events"
      ;;
    'users')
      url="${API_TYPE}/${API_OWNER}/events/public"
      ;;
    *)
      echo "[ERROR] UNKNOWN API TYPE!"
      exit 1
      ;;
  esac

  local api="${url}"
  echo "Get '${api}'..." && _gh_file "${api}" "${dir}/events.json"

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: ORG MEMBERS.
# -------------------------------------------------------------------------------------------------------------------- #

gh_org_members() {
  echo "--- [GITHUB] ${API_OWNER^^} / MEMBERS"
  _pushd "${d_src}" || exit 1

  local dir="${API_DIR}/orgs/${API_OWNER}/members"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local users
  readarray -t users < <( _gh_list "orgs/${API_OWNER}/members" ".[].login" )

  for user in "${users[@]}"; do
    local api_user="users/${user}"
    local dir_user="${dir}/${user}"
    [[ ! -d "${dir_user}" ]] && _mkdir "${dir_user}"
    echo "Get '${api_user}'..." && _gh_file "${api_user}" "${dir_user}/info.json"
    echo "Get '${api_user}/gpg_keys'..." && _gh_file "${api_user}/gpg_keys" "${dir_user}/gpg.json"
  done

  ${jq} -nc '$ARGS.positional' --args "${users[@]}" > "${dir%/*}/members.json"

  _popd || exit 1
}

# -------------------------------------------------------------------------------------------------------------------- #
# API: ORG OUTSIDE COLLABORATORS.
# -------------------------------------------------------------------------------------------------------------------- #

gh_org_collaborators() {
  echo "--- [GITHUB] ${API_OWNER^^} / COLLABORATORS"
  _pushd "${d_src}" || exit 1

  local dir="${API_DIR}/orgs/${API_OWNER}/collaborators"
  [[ ! -d "${dir}" ]] && _mkdir "${dir}"

  local users
  readarray -t users < <( _gh_list "orgs/${API_OWNER}/outside_collaborators" ".[].login" )

  for user in "${users[@]}"; do
    local api_user="users/${user}"
    local dir_user="${dir}/${user}"
    [[ ! -d "${dir_user}" ]] && _mkdir "${dir_user}"
    echo "Get '${api_user}'..." && _gh_file "${api_user}" "${dir_user}/info.json"
    echo "Get '${api_user}/gpg_keys'..." && _gh_file "${api_user}/gpg_keys" "${dir_user}/gpg.json"
  done

  ${jq} -nc '$ARGS.positional' --args "${users[@]}" > "${dir%/*}/collaborators.json"

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
    && ${git} commit -a -m "GitHub API: ${ts}" \
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

# API: Get items.
_gh() {
  ${gh} api "${1}" -q "${2}"
}

# API: Get list items.
_gh_list() {
  ${gh} api --paginate "${1}" -q "${2}" | sort
}

# API: Download items to file.
_gh_file() {
  ${gh} api "${1}" > "${2}"
}

_gh_rate() {
  local limit; limit=$( _gh 'rate_limit' '.rate.limit' )
  local used; used=$( _gh 'rate_limit' '.rate.used' )
  local remaining; remaining=$( _gh 'rate_limit' '.rate.remaining' )
  local reset; reset=$( _gh 'rate_limit' '.rate.reset' )
  reset=$( date +'%Y-%m-%d %H:%M:%S' -d "@${reset}" )

  read -r -d '' rate_help <<- EOF
Your current rate:
  Limit: ${limit}
  Used: ${used}
  Remaining: ${remaining}
  Reset: ${reset}
EOF

  echo "${rate_help}"
}

# -------------------------------------------------------------------------------------------------------------------- #
# -------------------------------------------------< INIT FUNCTIONS >------------------------------------------------- #
# -------------------------------------------------------------------------------------------------------------------- #

init "$@"; exit 0
