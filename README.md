# minibot

A small Dependabot-style bot, written to learn how automated dependency updates
work from the inside. It finds outdated or vulnerable dependencies and opens pull
requests that update them, using the same architecture as
[dependabot-core](https://github.com/dependabot/dependabot-core).

Supported ecosystems: **Bundler** (npm next).

## How it works

```
.github/minibot.yml
        │
        ▼
 ┌─────────────┐   ┌────────────┐   ┌───────────────┐   ┌─────────────┐   ┌────────────────────┐
 │ FileFetcher │──▶│ FileParser │──▶│ UpdateChecker │──▶│ FileUpdater │──▶│ PullRequestCreator │
 └─────────────┘   └────────────┘   └───────────────┘   └─────────────┘   └────────────────────┘
  Gemfile,          Dependency        latest version     new Gemfile +      branch, commit and PR
  Gemfile.lock      objects           (rubygems.org)     Gemfile.lock       via the GitHub API
  (GitHub API or    (name, version,   advisories         (Bundler's own
   local checkout)   requirement)     (osv.dev)          resolver)
```

| Layer | Path | Knows about Ruby? |
|---|---|---|
| Shared models, OSV client, config, updater loop, PR creation | `lib/minibot/common/` | No |
| Bundler plugin: fetcher, parser, update checker, file updater, metadata | `lib/minibot/bundler/` | Yes |

Each ecosystem registers its classes, for example
`Minibot::FileParsers.register("bundler", Bundler::FileParser)`, and the shared
code looks them up by the `package-ecosystem` value in the config. Adding npm
means adding `lib/minibot/npm/` with no change to `common/`.

### Update strategies

For each dependency, minibot picks a target version, then tries:

1. **widen**: change the manifest requirement (`~> 12.3` → `~> 13.4`) and re-resolve.
2. **lockfile_only**: keep the requirement and move only the lockfile as far as it allows.

The fallback matters. In `examples/ruby-app`, rack 3 can't be installed because
`sinatra 2.x` requires `rack ~> 2.2`, so minibot falls back to rack 2.2.25. That
still fixes 35 CVEs.

### Version updates vs security updates

| | Target | Example |
|---|---|---|
| default | latest stable release | rake 12.3.2 → 13.4.2 |
| `--security-only` | lowest release that fixes every advisory affecting the current version | rake 12.3.2 → 12.3.3 |

## Usage

```bash
bundle install

# Plan only: print the PRs and diffs without touching GitHub
bundle exec bin/minibot --repo MahmoudMShehata/minibot --local . --dry-run
bundle exec bin/minibot --repo MahmoudMShehata/minibot --local . --dry-run --security-only

# Open real PRs (needs a token with contents + pull-requests write)
GITHUB_TOKEN=... bundle exec bin/minibot --repo MahmoudMShehata/minibot --local .
```

Configuration (`.github/minibot.yml`) follows the `dependabot.yml` schema:

```yaml
version: 1
updates:
  - package-ecosystem: bundler
    directory: /examples/ruby-app
    open-pull-requests-limit: 5
    ignore:
      - dependency-name: rspec
        versions: [">= 4"]
```

It also runs weekly in GitHub Actions; see `.github/workflows/minibot.yml`.

## Tests

```bash
bundle exec rspec                    # everything
bundle exec rspec --tag '~network'   # offline only (skips the real `bundle lock` tests)
```

## Known gaps compared with Dependabot

- **Running untrusted code.** A Gemfile is Ruby, so parsing it executes code from the
  target repo. Dependabot runs ecosystem helpers in isolated containers; minibot runs
  them in-process.
- **Resolution happens late.** minibot learns whether a target resolves only in the
  FileUpdater. Dependabot's UpdateChecker resolves first, so it knows the
  *latest resolvable* version before it writes any files.
- **Exact security targets.** In lockfile-only mode, `bundle lock --update` goes to the
  newest version the requirement allows, not exactly the lowest fixed one.
- **Overlapping PRs.** Updating sinatra also moves rack, so the sinatra and rack PRs
  conflict once one is merged. Dependabot rebases or recreates PRs (`@dependabot rebase`)
  and supports grouped updates.
- **Transitive dependencies.** Only gems declared in the Gemfile are updated.
- **Private registries and credentials.** Not handled. Dependabot routes registry
  traffic through a credentials proxy.
- **CI on bot PRs.** PRs opened with the Actions `GITHUB_TOKEN` don't trigger other
  workflows; a GitHub App or PAT is needed for that.
