# Releasing

Pandatone is not published to RubyGems. A release is a tag, and a host takes
the gem from it:

```ruby
gem "pandatone", github: "bobbymeyer/pandatone", tag: "v0.1.0"
```

`.github/workflows/release.yml` runs on the tag: it checks that the tag and
`Pandatone::VERSION` agree, runs RuboCop and the suite, builds the gem and
opens a GitHub release carrying it. A tag that disagrees with the gemspec
fails before anything is released.

## Cutting a version

1. `lib/pandatone/version.rb` — set the version.
2. `CHANGELOG.md` — turn the unreleased section into the version, with a date.
3. Merge to `main`.
4. Tag it, from `main`:

   ```sh
   git tag v0.1.0
   git push origin v0.1.0
   ```

5. Move each host's Gemfile to the new tag.
