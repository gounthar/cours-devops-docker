# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a French Docker DevOps course presentation repository that generates slide decks using:
- **AsciiDoctor** for content authoring (`.adoc` files)
- **Reveal.js** for HTML slide presentation
- **Gulp** for build pipeline and development server
- **Docker & Docker Compose** for containerized development environment

The slides are written in AsciiDoctor language and rendered as HTML and PDF using reveal.js.

## Common Development Commands

All development is done through containerized Make commands:

### Build Commands
- `make build` - Generate slides in "one shot" mode (outputs to `./dist/index.html`)
- `make pdf` - Generate PDF version of slides
- `make all` - Full pipeline: clean, build, and verify
- `make clean` - Remove generated files and Docker containers

### Development Commands
- `make serve` - Start development server with live-reloading at http://localhost:8000
- `make shell` - Get interactive shell inside the build container
- `make verify` - Validate HTTP links and HTML w3c compliance (currently disabled)

### Dependency Management
- `make dependencies-update` - Update `package.json` to latest versions using ncu (npm-check-updates)
- `make dependencies-lock-update` - Generate/update `package-lock.json`

### Updatecli Integration
- Updatecli automatically manages Docker image version updates in course examples
- GitHub Action (`.github/workflows/updatecli.yaml`) runs weekly on Mondays at 2am UTC
- Manifest files in `updatecli/updatecli.d/` track versions for: Node, Maven, Nginx, Tomcat, Golang, and WAR files
- On main branch, Updatecli automatically creates PRs with version bumps
- Values configured in `updatecli/values.github-action.yaml`

## Architecture & Structure

### Content Organization
- `content/` - AsciiDoctor source files
  - `index.adoc` - Main presentation file that includes all chapters using AsciiDoc `include::` directives
  - `attributes.adoc` - Global AsciiDoctor configuration and variables (reveal.js settings, icons, URLs)
  - `chapitres/` - Individual chapter files in French (welcome, intro, cas-d-usage, dev-env, cli, git-base, docker-base, images, volumes, reseaux, compose, bonus, bibliographie)
  - `chapitres/sous-chapitres/` - Sub-sections for complex chapters
  - `media/` - Images, videos, and other media assets (including auto-generated `qrcode.png`)
  - `code-samples/` - Code examples referenced in slides (organized by chapter/topic)

### Build System
- `gulp/gulpfile.js` - Gulp build configuration that:
  - Converts AsciiDoctor files to HTML using reveal.js backend
  - Processes SCSS styles to CSS
  - Copies and prepares reveal.js plugins and dependencies
  - Sets up BrowserSync for live-reloading during development
- `npm-packages/package.json` - NPM dependencies for build tools
- `docker-compose.yml` - Defines containerized build environment with services:
  - `serve` - Development server with live-reload
  - `build` - One-shot build process
  - `qrcode` - Generates QR codes for presentation URLs
  - `pdf` - PDF generation service

### Docker Configuration
- `Dockerfile` - Node.js Alpine-based build environment with Gulp, AsciiDoctor, and dependencies
- `dockerfiles/pdf/Dockerfile` - Separate PDF generation container using decktape (ghcr.io/astefanutti/decktape)
- `.env` - Environment variables for local development (optional, can be overridden)
- All build operations run inside containers to ensure consistency
- Uses Docker Compose with build caching via `DOCKER_BUILDKIT=1`

## Key Environment Variables
- `PRESENTATION_URL` - URL where slides will be hosted (used for QR codes and footer links)
- `REPOSITORY_URL` - Git repository URL (displayed in slides)
- `DIST_DIR` - Output directory on host (default: `./dist`)
- `BUILD_DIR` - Temporary build directory inside container (default: `/tmp/dist`, uses tmpfs for faster I/O)
- `CURRENT_UID` - User ID for file ownership (automatically set by docker-compose from host user)
- `DOCKER_BUILDKIT` - Enable Docker BuildKit for faster builds (default: `1`)
- `COMPOSE_DOCKER_CLI_BUILD` - Use Docker CLI build (default: `1`)

## CI/CD Pipeline
- **Main Build Workflow** (`.github/workflows/build-workflow.yml`):
  - Triggers on push to any branch (except `gh-pages`), PRs, tags, and manual dispatch
  - Builds HTML slides via `make build`
  - Generates PDF version via `make pdf` (reuses HTML build)
  - Deploys to GitHub Pages at branch-specific subdirectories (e.g., `main/`, `feature-branch/`)
  - Uses `peaceiris/actions-gh-pages` for deployment
- **Updatecli Workflow** (`.github/workflows/updatecli.yaml`):
  - Runs weekly (Mondays 2am UTC) and on push/PR
  - Checks for Docker image updates in course examples
  - Automatically creates PRs when new versions available (main branch only)

## Development Workflow
1. Edit `.adoc` files in `content/` directory
2. Run `make serve` for live development with auto-reload
3. Access slides at http://localhost:8000
4. Changes to content, styles, or media are automatically reflected

## File Modifications
- **Content changes**: Edit `.adoc` files in `content/chapitres/` or `content/chapitres/sous-chapitres/`
- **Styling**: Modify SCSS file at `assets/styles/custom-revealjs.scss`
- **Build configuration**: Modify `gulp/gulpfile.js` (located in `gulp/` directory)
- **NPM Dependencies**: Update `npm-packages/package.json` then run `make dependencies-lock-update`
- **Code examples**: Add/modify files in `content/code-samples/` (organized by topic)
- **Media assets**: Add images/videos to `content/media/` (QR code auto-generated, don't edit manually)
- **Global settings**: Edit `content/attributes.adoc` for reveal.js settings, author info, URLs, etc.

## Presentation Features
- Multi-chapter structure with navigation controls (arrow keys, overview with 'o' key)
- Syntax highlighting via highlight.js for multiple languages (Groovy, Dockerfile, YAML, JSON, Bash, Java, JavaScript, XML, SQL, Properties, Markdown, etc.)
- QR code auto-generation for easy mobile access to slides
- PDF export capability using decktape with Puppeteer
- Responsive design with custom theming (SCSS compiled to CSS)
- CopyCode plugin for easy code snippet copying
- Menu plugin for slide navigation
- Reveal.js plugins: chalkboard, audio-slideshow, animate, chart, and more

## Important Technical Details
- **Build Process Flow**: QR code generation → parallel asset preparation (reveal.js, plugins, styles, media) → AsciiDoc to HTML conversion → copy to dist/
- **Live Reload**: BrowserSync watches `.adoc`, `.scss`, and media files for changes during `make serve`
- **File Permissions**: Docker containers run as `CURRENT_UID` to avoid permission issues with generated files
- **Performance**: Uses tmpfs mount for `BUILD_DIR` inside containers for faster I/O operations
- **Node Version**: Currently using Node.js 24 on Alpine Linux
- **AsciiDoctor Backend**: Uses `@asciidoctor/reveal.js` converter for reveal.js-compatible HTML output