# GitHub API Fetch

Action для скачивания ответов GitHub API и сохранения их в указанном репозитории. Этот Action необходим в качестве "проксирования" ответов API для использования в различных JAMstack приложениях, чтобы лишний раз не дёргать исходный GitHub API.

## Workflow Syntax

```yml
name: "API Fetch"

on:
  schedule:
    - cron:  '0 */6 * * *'

jobs:
  build:
    runs-on: ubuntu-latest
    name: "Build"
    steps:
      - name: "GitHub API"
        uses: ghastore/api-github@main
        with:
          git_repo: "${{ github.server_url }}/${{ github.repository }}.git"
          git_user: "${{ secrets.USER_NAME }}"
          git_email: "${{ secrets.USER_EMAIL }}"
          git_token: "${{ secrets.USER_TOKEN }}"
          api_dir: "api/github"
          api_type: "orgs"
          api_owner: "github"
          api_token: "${{ secrets.USER_TOKEN }}"
```

## Legend

- `git_repo`  
  Ссылка на репозиторий, в котором необходимо хранить ответы API.
- `git_user`  
  Логин пользователя GitHub.
- `git_email`  
  Email пользователя GitHub.
- `git_token`  
  Токен пользователя GitHub.
- `api_dir`  
  Локальная директория, в которую будут сохраняться ответы API. По умолчанию: `api/github`.
- `api_type`  
  Тип вызова API. Может принимать значения `orgs` или `users` для вызова API организаций или API пользователей, соответственно.
- `api_owner`  
  Хозяин данных. Это может быть либо логин организации, либо логин пользователя.
- `api_token`  
  Токен для вызова API. Можно использовать отдельный токен пользователя для обращения к GitHub API.
