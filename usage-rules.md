# TableauRefLinkExtension Usage Rules

TableauRefLinkExtension is a Tableau extension that resolves reference links to
pages, posts, and static assets within your Tableau site.

## Core Behavior

Processes links with special prefixes in HTML attributes:

1. `$ref:` - Resolves to content files (pages, posts) or static assets
2. `$site:` - Resolves to paths relative to site base URL

Works with `href` and `src` attributes on supported HTML elements.

## Configuration Format

```elixir
config :tableau, TableauRefLinkExtension,
  enabled: true,           # optional, default: true
  prefix: "$ref",          # optional, default: "$ref"
  site_prefix: "$site"     # optional, default: "$site"
```

Colons are automatically added to prefixes if omitted.

## Reference Link Resolution (`$ref:`)

### Filename Matching (no `/` in path)

```markdown
[My Post]($ref:2024-01-15-my-post.md)
[About Page]($ref:about.md)
```

Searches for files with matching filename across all content and static assets.

### Path Matching (contains `/`)

```markdown
[Specific Post]($ref:_posts/2024-01-15-my-post.md)
[Asset]($ref:images/logo.png)
```

Matches against full file paths from workspace root.

### With Anchors

```markdown
[Section Link]($ref:post.md#section)
```

Anchor fragments are preserved in resolved URLs.

## Site-Relative Path Resolution (`$site:`)

```markdown
[Direct Path]($site:downloads/doc.pdf)
[Secret File]($site:secret/file.txt)
```

Resolves paths directly relative to site base URL without content lookup.

The `$site:` prefix means "site base URL path + this absolute path". For example:

- Site URL `http://example.com` → `$site:file.txt` becomes `/file.txt`
- Site URL `http://example.com/blog` → `$site:file.txt` becomes `/blog/file.txt`

## Resolution Strategy

### For `$ref:` links

1. **Content files** (pages, posts) are checked first
2. **Static assets** from Tableau's `include_dir` (default: `extra/`) are checked second
3. **Missing references** become `#ref-not-found:path` with warning logged
4. **Ambiguous matches** (multiple files with same name) use first match with
   warning logged

### For `$site:` links

- Path is resolved relative to the site's base URL path
- No content lookup or validation is performed

### Base URL Path Impact

The site's base URL path (from Tableau config `url:`) affects ALL resolved links:

- `$ref:` links have the base path prepended to their resolved permalinks
- `$site:` links have the base path prepended to their specified paths

Examples:
- Site URL `http://example.com` (base path `/`)
  - `$ref:post.md` → `/posts/post`
  - `$site:file.txt` → `/file.txt`
- Site URL `http://example.com/blog` (base path `/blog`)
  - `$ref:post.md` → `/blog/posts/post`
  - `$site:file.txt` → `/blog/file.txt`

## Supported HTML Elements

### `href` attribute

- `<a>` - links
- `<link>` - stylesheets, alternate links

### `src` attribute

- `<img>` - images
- `<audio>`, `<video>` - media
- `<source>`, `<track>` - media sources
- `<embed>`, `<iframe>` - embedded content
- `<script>` - scripts

## Examples

### Markdown Links

```markdown
<!-- Reference to post by filename -->
[Read my post]($ref:2024-01-15-my-post.md)

<!-- Reference with path -->
[About page]($ref:pages/about.md)

<!-- Reference to static asset -->
![Logo]($ref:logo.png)

<!-- Site-relative path to file -->
[Download PDF]($site:downloads/guide.pdf)

<!-- With anchor -->
[Jump to section]($ref:guide.md#installation)
```

### HTML Elements

```html
<!-- Link -->
<a href="$ref:about.md">About</a>

<!-- Image -->
<img src="$ref:images/photo.jpg" alt="Photo">

<!-- Stylesheet -->
<link rel="stylesheet" href="$site:css/custom.css">

<!-- Script -->
<script src="$ref:scripts/analytics.js"></script>
```

## Resolution Output

### Successful Resolution

```markdown
[My Post]($ref:2024-01-15-my-post.md)
```

Becomes:

```html
<a href="/posts/2024/01/15/my-post">My Post</a>
```

### Failed Resolution

```markdown
[Missing]($ref:nonexistent.md)
```

Becomes:

```html
<a href="#ref-not-found:nonexistent.md">Missing</a>
```

Development mode logs warning with available files for debugging.

### Ambiguous Resolution

Multiple files named `about.md` in different directories:

```markdown
[About]($ref:about.md)
```

Uses first match found and logs warning listing all matches. Use path matching
to disambiguate:

```markdown
[About]($ref:pages/about.md)
```

## Common Issues

1. **Reference not found**: File doesn't exist or isn't in content/static
   directories. Check spelling and file location.

2. **Ambiguous references**: Multiple files with same name. Use path matching
   with `/` to specify exact file.

3. **Wrong prefix**: Using `$ref:` for direct paths or `$site:` for content
   lookups. Use `$ref:` for content files, `$site:` for direct paths.

4. **Static assets not indexed**: Files must be in Tableau's `include_dir`
   (default: `extra/`) to be found by `$ref:` resolution. This directory is
   configurable in Tableau's site config.

5. **Anchor fragments**: Anchors are preserved but not validated. Ensure target
   page has matching anchor ID.

6. **Base URL path confusion**: Remember that both `$ref:` and `$site:` links
   are automatically prefixed with the site's base URL path. Don't manually add
   the base path to your links.

## Resources

- [HexDocs](https://hexdocs.pm/tableau_ref_link_extension) - Full API
  documentation
