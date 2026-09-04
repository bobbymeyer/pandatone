# Releasing

Versions go out from a tag, built and pushed by
`.github/workflows/release.yml`. **No RubyGems API key exists in this
repository or in its secrets**, and none should be created: the workflow
authenticates over OIDC, with a short-lived credential RubyGems mints for
this repository and this workflow file alone.

## Cutting a version

1. `lib/pandatone/version.rb` — set the version.
2. `CHANGELOG.md` — turn the unreleased section into the version, with a date.
3. Merge to `main`.
4. Tag it, from `main`:

   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```

The workflow checks that the tag and `Pandatone::VERSION` agree, runs RuboCop
and the suite, builds, pushes to RubyGems and opens a GitHub release. A tag
that disagrees with the gemspec fails before anything is published, and a tag
for a version already out skips the push rather than failing.

## One-time setup on rubygems.org

Trusted publishing has to be configured once before the first release, and
because `pandatone` does not exist on RubyGems yet this is the **pending**
publisher flow — RubyGems lets you register a publisher for a name that has
never been pushed, which then creates the gem on the first run.

Under your rubygems.org profile, in the trusted publishers section, add a
GitHub Actions publisher with:

| Field | Value |
| --- | --- |
| Gem name | `pandatone` |
| Repository owner | `bobbymeyer` |
| Repository name | `pandatone` |
| Workflow filename | `release.yml` |
| Environment | leave empty |

Docs: <https://guides.rubygems.org/trusted-publishing/>

## The manual path

If trusted publishing is not set up, or a release has to go out from a
machine rather than from CI:

```sh
gem build pandatone.gemspec
gem push pandatone-0.1.0.gem
```

The gemspec sets `rubygems_mfa_required`, so this prompts for an OTP. Keep it
that way — it is the reason an API key on its own cannot publish this gem.
