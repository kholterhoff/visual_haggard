# GitHub Pages Publishing

This repository is designed for a local-authoring, static-publish workflow:

- `main` contains the Rails source app
- `gh-pages` contains the generated static site
- GitHub Pages serves the `gh-pages` branch
- Rails stays local and is not deployed publicly

## One-Time Setup

1. Create the first commit on `main` and push it to GitHub.
2. In GitHub repository settings, configure Pages to publish from the `gh-pages` branch at the repository root.
3. Configure your custom domain DNS to point at GitHub Pages.
4. Set the custom domain in GitHub Pages settings to match the `CUSTOM_DOMAIN` value you will use locally.

## Local Publish Workflow

From the Rails repo root:

```bash
cd /Users/kateholterhoff/Documents/code/visual_haggard
bin/publish_gh_pages
```

That command will:

1. run `bin/rails static:export`
2. build the Pagefind index inside `dist/`
3. create or reuse a local `gh-pages` worktree at `../visual_haggard_pages`
4. sync `dist/` into that worktree
5. commit the static output on `gh-pages`
6. push `gh-pages` to `origin`

## Environment Variables

Useful overrides:

```bash
PAGES_REMOTE=origin
PAGES_BRANCH=gh-pages
PAGES_WORKTREE=/Users/kateholterhoff/Documents/code/visual_haggard_pages
STATIC_HOST=www.visualhaggard.org
STATIC_REQUEST_HOST=127.0.0.1
CUSTOM_DOMAIN=www.visualhaggard.org
PAGEFIND_CMD="npx pagefind"
PAGES_COMMIT_MESSAGE="Publish archive update"
RUN_EXPORT=true
```

Example with an explicit Pagefind command:

```bash
PAGEFIND_CMD="npx pagefind" bin/publish_gh_pages
```

## Export Artifacts

The static export writes GitHub Pages-specific files automatically:

- `.nojekyll`
- `CNAME` when `CUSTOM_DOMAIN` is set
- `404.html`
- `pagefind/` search index

## Operational Notes

- Publishing requires a committed `main` branch and a configured `origin` remote.
- The script assumes `gh-pages` is dedicated to static output and will replace its working tree contents with `dist/`.
- If Pagefind is missing, static export will warn and the published search UI will not work until the index is rebuilt.
- `STATIC_REQUEST_HOST` controls the local host used for the export requests. Leave it at `127.0.0.1` unless your local Rails environment explicitly allows another host.
- If any public page still renders `/rails/active_storage/...`, the export report will flag it as a static-publish warning.
