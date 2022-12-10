FROM alpine

LABEL "name"="GitHub API"
LABEL "description"=""
LABEL "maintainer"=""
LABEL "repository"=""
LABEL "homepage"="https://github.com/ghastore"

COPY *.sh /
RUN apk add --no-cache bash curl git git-lfs github-cli jq

ENTRYPOINT ["/entrypoint.sh"]
