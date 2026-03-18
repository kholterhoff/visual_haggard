# Agent Workflow

## Canonical Workspace
- Use `/Users/kateholterhoff/Documents/code/visual_haggard` as the working repo.
- Do not work from the legacy path `/Users/kateholterhoff/Documents/code/BobVH/visual_haggard`.

## Frontend Source Of Truth
- Edit source assets only:
  - `app/assets/stylesheets/*.css`
  - views in `app/views/`
  - JS in `app/javascript/`
- Do not hand-edit generated output:
  - `public/assets/`
  - `dist/`
  - `/Users/kateholterhoff/Documents/code/visual_haggard_pages/`

## CSS Ownership
- Put shared typography, buttons, layout, and generic card styles in `app/assets/stylesheets/layout.css`.
- Put homepage-only styles in `app/assets/stylesheets/home.css`.
- Namespace homepage-only overrides under `.home-index` or `.home-page` when possible.
- If a change affects one archive surface only, prefer that page stylesheet over `layout.css`.

## Public Asset Manifest Guardrail
- Keep `app/assets/stylesheets/application.css` explicit.
- Do not use `require_tree .` in the public stylesheet manifest.
- Do not include `active_admin` in the public stylesheet manifest.
- ActiveAdmin must stay isolated to its own stylesheet so admin selectors never bleed into the public archive.

## Local CSS Recovery
- If a CSS change does not appear locally, do not patch `public/assets`.
- Run `bin/reset_local_assets`.
- Restart `bin/rails server`.
- Hard refresh the browser.

## Static Publish Workflow
- Use `bin/publish_gh_pages` to publish the static site.
- Static export is driven by `app/services/static_site_exporter.rb`.
- The export flow cleans generated `public/assets` and `tmp/cache/assets` after a build so local development does not reuse stale compiled assets.

## Verification
- Verify source files first, not compiled assets.
- If a GitHub Pages deploy looks stale, compare the asset digest in:
  - `dist/index.html`
  - `/Users/kateholterhoff/Documents/code/visual_haggard_pages/index.html`
  - the live HTML from `https://www.visualhaggard.org`
- If a public UI suddenly picks up Helvetica, generic admin button styles, or boxed `.panel` / `.section` treatment, inspect `app/assets/stylesheets/application.css` first.
