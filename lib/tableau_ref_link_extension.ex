defmodule TableauRefLinkExtension do
  @moduledoc """
  Tableau extension that resolves internal content references in rendered HTML.

  Replaces special link prefixes with actual URLs:

  - `$ref:` - Resolves to pages, posts, or static assets by filename or path
  - `$site:` - Direct site-relative paths without content lookup

  ### Configuration

      config :tableau, TableauRefLinkExtension,
        enabled: true,
        prefix: "$ref",
        site_prefix: "$site"

  Colons are automatically added to prefixes if omitted.

  ### Reference Link Syntax

  **Content references** (`$ref:`) search for matching files:

  - `[text]($ref:file.md)` - Filename matching across all content
  - `[text]($ref:_posts/2024-01-15-post.md)` - Path matching
  - `[text]($ref:file.md#section)` - Anchors are preserved

  **Site-relative paths** (`$site:`) resolve directly:

  - `[text]($site:downloads/doc.pdf)` - No content lookup, just path resolution

  ### Resolution Strategy

  For `$ref:` links:

  - References with `/` match against full file paths
  - References without `/` match by filename only
  - Content files (pages, posts) take precedence over static assets
  - Static assets are indexed from Tableau's `include_dir` (default: `extra/`)
  - Missing references become `#ref-not-found:path` with warning
  - Ambiguous matches (multiple files with same name) use first match with warning

  For `$site:` links:

  - Path is resolved relative to the site's base URL
  - If site URL is `http://example.com/blog`, then `$site:file.txt` becomes `/blog/file.txt`
  - If site URL has no path component, resolves to `/file.txt`

  ### Base URL Path Handling

  The site's base URL path (from `config :tableau, :config, url: "..."`) affects all
  resolved links:

  - URL `http://example.com` → base path `/` → `$ref:post.md` becomes `/posts/post`
  - URL `http://example.com/blog` → base path `/blog` → `$ref:post.md` becomes `/blog/posts/post`

  Both `$ref:` and `$site:` links are prefixed with the base path automatically.

  ### Supported Elements

  Works with `href` and `src` attributes on:

  - `<a>`, `<link>` - `href` attribute
  - `<img>`, `<audio>`, `<video>`, `<source>`, `<track>`, `<embed>`, `<iframe>`, `<script>` - `src` attribute
  """

  use Tableau.Extension, key: :ref_links, priority: 800

  require Logger

  @defaults %{enabled: true, prefix: "$ref:", site_prefix: "$site:"}

  @impl Tableau.Extension
  def config(config) when is_list(config), do: config(Map.new(config))

  def config(config) do
    merged = Map.merge(@defaults, config)

    {:ok,
     %{
       enabled: merged.enabled,
       prefix: normalize_prefix(merged.prefix, @defaults.prefix),
       site_prefix: normalize_prefix(merged.site_prefix, @defaults.site_prefix)
     }}
  end

  @impl Tableau.Extension
  def pre_build(token) do
    base_url_path =
      case URI.parse(token.site.config.url) do
        %{path: nil} -> "/"
        %{path: path} -> path
      end

    content_map = build_content_map(token)

    {:ok, Map.put(token, :ref_links, %{content_map: content_map, base_url_path: base_url_path})}
  end

  @impl Tableau.Extension
  def pre_write(token) do
    ref_links = Map.put(token.ref_links, :config, token.extensions.ref_links.config)
    {:ok, put_in(token.site.pages, Enum.map(token.site.pages, &process_page(&1, ref_links)))}
  end

  defp resolve_ref(ref_path, content_map, base_url_path, _prefix) do
    {path, anchor} = split_anchor(ref_path)

    permalink =
      if String.contains?(path, "/") do
        resolve_ref_by_path(content_map, path)
      else
        resolve_ref_by_filename(content_map, path)
      end

    prepend_base_path(permalink, base_url_path) <> anchor
  end

  defp resolve_ref_by_path(%{by_path: by_path}, path) do
    case Map.get(by_path, path) do
      nil ->
        Logger.warning("Reference not found: #{path}")
        "#ref-not-found:#{path}"

      permalink ->
        permalink
    end
  end

  defp resolve_ref_by_filename(%{by_filename: by_filename}, path) do
    case Map.get(by_filename, path) do
      nil ->
        Logger.warning("Reference not found: #{path}")
        "#ref-not-found:#{path}"

      [permalink] ->
        permalink

      [permalink | _rest] = matches ->
        files_preview =
          matches
          |> Enum.take(2)
          |> Enum.join(", ")

        Logger.warning(
          "Ambiguous reference '#{path}' matches #{length(matches)} files (#{files_preview}), using first match"
        )

        permalink
    end
  end

  defp prepend_base_path(permalink, "/"), do: permalink
  defp prepend_base_path(permalink, base_path), do: base_path <> permalink

  defp resolve_base_ref(ref_path, base_url_path) do
    {path, anchor} = split_anchor(ref_path)

    resolved =
      if base_url_path == "/" do
        "/" <> path
      else
        base_url_path <> "/" <> path
      end

    resolved <> anchor
  end

  defp normalize_prefix(nil, default), do: default
  defp normalize_prefix("", default), do: default

  defp normalize_prefix(prefix, _default) when is_binary(prefix) do
    if String.ends_with?(prefix, ":") do
      prefix
    else
      prefix <> ":"
    end
  end

  defp normalize_prefix(_invalid, default), do: default

  defp build_content_map(token) do
    content_items = Map.get(token, :posts, []) ++ Map.get(token, :pages, [])
    by_path = Map.new(content_items, &{&1.file, &1.permalink})
    by_filename = Enum.group_by(content_items, &Path.basename(&1.file), & &1.permalink)
    {asset_by_path, asset_by_filename} = scan_static_assets(token.site.config.include_dir)

    # Merge assets and content, with content taking precedence
    %{
      by_path: Map.merge(asset_by_path, by_path),
      by_filename:
        Map.merge(asset_by_filename, by_filename, fn _k, assets, content ->
          content ++ assets
        end)
    }
  end

  defp scan_static_assets(nil), do: {%{}, %{}}

  defp scan_static_assets(extra_dir) do
    if File.dir?(extra_dir) do
      assets =
        extra_dir
        |> Path.join("**/*")
        |> Path.wildcard()
        |> Enum.filter(&File.regular?/1)
        |> Enum.map(fn path ->
          rel_path = Path.relative_to(path, extra_dir)
          url = "/" <> rel_path
          {rel_path, url}
        end)

      by_path =
        assets
        |> Enum.filter(fn {rel_path, _url} -> String.contains?(rel_path, "/") end)
        |> Map.new()

      by_filename =
        Enum.group_by(
          assets,
          fn {rel_path, _url} -> Path.basename(rel_path) end,
          fn {_rel_path, url} -> url end
        )

      {by_path, by_filename}
    else
      {%{}, %{}}
    end
  end

  defp process_page(page, ref_links) do
    case Floki.parse_document(page.body) do
      {:ok, html} ->
        put_in(page.body, replace_ref_links(html, ref_links))

      # coveralls-ignore-start
      {:error, reason} ->
        Logger.warning("Failed to parse HTML for page #{page.permalink}: #{inspect(reason)}")
        page
        # coveralls-ignore-stop
    end
  end

  defp replace_ref_links(html, ref_links) do
    html
    |> Floki.traverse_and_update(&replace_ref_link(&1, ref_links))
    |> Floki.raw_html()
  end

  # Elements with `href`
  defp replace_ref_link({tag, attrs, children} = element, ref_links) when tag in ["a", "link"] do
    transform_element(tag, "href", element, attrs, children, ref_links)
  end

  defp replace_ref_link({tag, attrs, children} = element, ref_links)
       when tag in ["img", "audio", "video", "source", "track", "embed", "iframe", "script"] do
    transform_element(tag, "src", element, attrs, children, ref_links)
  end

  defp replace_ref_link(element, _ref_links), do: element

  defp transform_element(tag, attr, element, attrs, children, ref_links) do
    case List.keyfind(attrs, attr, 0) do
      {^attr, value} ->
        transform_attribute(tag, attr, value, attrs, children, ref_links)

      nil ->
        element
    end
  end

  # Map tags to their reference attributes

  defp transform_attribute(tag, attr_name, value, attrs, children, ref_links) do
    prefix = ref_links.config.prefix
    site_prefix = ref_links.config.site_prefix

    cond do
      String.starts_with?(value, prefix) ->
        ref_path = String.replace_prefix(value, prefix, "")
        resolved = resolve_ref(ref_path, ref_links.content_map, ref_links.base_url_path, prefix)
        updated_attrs = List.keyreplace(attrs, attr_name, 0, {attr_name, resolved})
        {tag, updated_attrs, children}

      String.starts_with?(value, site_prefix) ->
        ref_path = String.replace_prefix(value, site_prefix, "")
        resolved = resolve_base_ref(ref_path, ref_links.base_url_path)
        updated_attrs = List.keyreplace(attrs, attr_name, 0, {attr_name, resolved})
        {tag, updated_attrs, children}

      true ->
        {tag, attrs, children}
    end
  end

  defp split_anchor(path) do
    case String.split(path, "#", parts: 2) do
      [path_part, anchor_part] -> {path_part, "#" <> anchor_part}
      [path_part] -> {path_part, ""}
    end
  end
end
