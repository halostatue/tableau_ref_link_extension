# TableauRefLinkExtension

- code :: <https://github.com/halostatue/tableau_ref_link_extension>
- issues :: <https://github.com/halostatue/tableau_ref_link_extension/issues>

A Tableau extension that resolves reference links to pages, posts, and static
assets within your Tableau site.

## Overview

The reference link extension resolves links prefixed with `$ref:` to a page,
post, or static asset based on the name. It also supports a `$site:` prefix for
direct site-relative path resolution.

```markdown
- [My Post]($ref:2024-01-15-my-post.md)
- [About Page]($ref:about.md)
- [With Anchor]($ref:post.md#section)
- [By Path]($ref:_posts/2024-01-15-my-post.md)
- [Secret File]($site:secret/file.txt)
- [Direct Path]($site:downloads/doc.pdf)
```

## Configuration

```elixir
config :tableau, TableauRefLinkExtension,
  enabled: true,
  prefix: "$ref",
  site_prefix: "$site"
```

Colons are automatically added to prefixes if omitted.

## Installation

TableauRefLinkExtension can be installed by adding `tableau_ref_link_extension`
to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tableau_ref_link_extension, "~> 1.0"}
  ]
end
```

Documentation is found on [HexDocs][docs].

## Semantic Versioning

TableauRefLinkExtension follows [Semantic Versioning 2.0][semver].

[12f]: https://12factor.net/
[docs]: https://hexdocs.pm/tableau_ref_link_extension
[semver]: https://semver.org/
