FROM alpine

LABEL "name"="GitHub API Fetch"
LABEL "description"="GitHub Action to get API responses and save them to repository."
LABEL "maintainer"="v77 Development <mail@v77.dev>"
LABEL "repository"="https://github.com/ghastore/api-github"
LABEL "homepage"="https://github.com/ghastore"

COPY *.sh /
RUN apk add --no-cache bash curl git git-lfs github-cli jq

ENTRYPOINT ["/entrypoint.sh"]
