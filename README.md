# Visual Haggard Archive - Rails Clone

A Ruby on Rails application that recreates the Visual Haggard archive, a digital collection of illustrations from H. Rider Haggard's Victorian novels.

## Overview

Visual Haggard is a digital archive intended to preserve, centralize, and improve access to the illustrations of popular Victorian novelist H. Rider Haggard (1856-1925). This Rails application provides a modern, searchable interface for browsing novels, editions, illustrations, and illustrators.

## Features

- **Admin Panel**: ActiveAdmin interface for local content management
- **Static Publishing**: Export the public archive to static HTML for GitHub Pages
- **Search Functionality**: Local Rails search plus Pagefind-backed static search
- **Tagging System**: Tag-based organization using acts-as-taggable-on
- **Image Management**: Legacy public image URLs plus attachment support for local authoring
- **Responsive Design**: Mobile-friendly interface
- **Web Scraping**: Tools to import content from the Wayback Machine archive

## Technology Stack

- **Ruby**: 3.2.2
- **Rails**: 7.1.6
- **Database**: PostgreSQL
- **Admin Panel**: ActiveAdmin
- **Search**: pg_search locally, Pagefind for the published static site
- **Tagging**: acts-as-taggable-on
- **Pagination**: Kaminari
- **Web Scraping**: HTTParty and Nokogiri

## Database Schema

### Core Models

- **Novel**: Haggard's novels with descriptions
- **Edition**: Different published editions of novels
- **Illustration**: Individual illustrations from editions
- **Illustrator**: Artists who created the illustrations
- **BlogPost**: Blog content about the archive
- **AdminUser**: Local admin account for ActiveAdmin

### Relationships

- A Novel has many Editions
- An Edition belongs to a Novel and has many Illustrations
- An Illustration belongs to an Edition and optionally to an Illustrator
- An Illustrator has many Illustrations
- BlogPosts can reference Novels, Editions, and Illustrations

## Installation

### Prerequisites

- Ruby 3.2.2
- PostgreSQL
- Node.js if you plan to use `npx pagefind`

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd visual_haggard
```

2. Install dependencies:
```bash
bundle install
```

3. Setup database:
```bash
bin/rails db:prepare
bin/rails db:seed
```

4. Start the server:
```bash
bin/rails server
```

5. Visit the application:
- Public site: http://localhost:3000
- Admin panel: http://localhost:3000/admin

### Default Admin Credentials

After running `bin/rails db:seed`, you can log in to the admin panel with:
- Email: `admin@example.com`
- Password: `password`

## Authoring Workflow

Use Rails locally to:

- manage novels, editions, illustrations, and illustrators in `/admin`
- preview changes at `http://localhost:3000`
- run import and maintenance tasks
- export a new static snapshot when the archive changes

### Importing Content

To import content from the Wayback Machine archive:

```bash
bin/rails scrape:wayback
```

To attach image files using the image references stored in the database (`illustrations.image_url`, `illustrations.image_file_name`, `editions.cover_url`, `editions.image_file_name`):

```bash
bin/rails images:attach_from_db
```

Useful options:

```bash
bin/rails images:attach_from_db DRY_RUN=yes
bin/rails images:attach_from_db ONLY=editions
bin/rails images:attach_from_db FORCE=yes
```

## Static Publishing

The public archive is intended to be published as a static site on GitHub Pages.

### Export the static site

```bash
bin/rails static:export
```

Useful options:

```bash
CUSTOM_DOMAIN=www.visualhaggard.org bin/rails static:export
PAGEFIND_CMD="npx pagefind" bin/rails static:export
RUN_PAGEFIND=false bin/rails static:export
```

The export writes `dist/` and includes:

- static HTML for the public archive pages
- `404.html`
- `.nojekyll`
- `CNAME` when `CUSTOM_DOMAIN` is set
- a `static_export_report.txt` file with warnings

### Publish to GitHub Pages

This repo is designed to use one remote repository with two branches:

- `main` for Rails source
- `gh-pages` for the generated static site

Publish locally with:

```bash
bin/publish_gh_pages
```

That script will:

1. run the static export
2. build the Pagefind index
3. create or reuse a local `gh-pages` worktree
4. sync `dist/` into the worktree
5. commit and push `gh-pages`

Detailed instructions are in [GITHUB_PAGES_PUBLISHING.md](/Users/kateholterhoff/Documents/code/visual_haggard/GITHUB_PAGES_PUBLISHING.md).

## Development

### Running Tests

```bash
bin/rails test
```

### Versioning And First Push

This repository is prepared to be pushed to GitHub.

Before the first push:

1. Keep `config/master.key` local. Do not commit it.
2. Keep real `.env` files local. Commit only `.env.example`.
3. Commit `config/credentials.yml.enc` only if you intend to use encrypted Rails credentials in the repo.
4. Review `git status` before the first commit so only source files, docs, migrations, fixtures, and `.keep` placeholders are included.

Example first push:

```bash
git add .
git commit -m "Initial import of Visual Haggard archive"
git remote add origin git@github.com:<account-or-org>/visual_haggard.git
git push -u origin main
```

After that, configure GitHub Pages to publish from the `gh-pages` branch.

## Deployment Model

This project is not intended to run as a public hosted Rails application.

Recommended model:

- Rails runs locally for editing and archive maintenance
- GitHub Pages serves the public archive from `gh-pages`
- Search is handled by Pagefind in the static export
- Public images must resolve to durable URLs; Rails blob URLs are not safe for the published site

## Additional References

- Static publish audit: [STATIC_PUBLISH_AUDIT.md](/Users/kateholterhoff/Documents/code/visual_haggard/STATIC_PUBLISH_AUDIT.md)
- GitHub Pages publishing workflow: [GITHUB_PAGES_PUBLISHING.md](/Users/kateholterhoff/Documents/code/visual_haggard/GITHUB_PAGES_PUBLISHING.md)
- S3 notes: [S3_SETUP.md](/Users/kateholterhoff/Documents/code/visual_haggard/S3_SETUP.md)
