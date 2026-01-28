defmodule TableauRefLinkExtensionTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  import TableauRefLinkExtension.PageHelpers

  describe "config/1" do
    test "accepts keyword list config" do
      assert {:ok, config} = TableauRefLinkExtension.config(enabled: true)
      assert config.enabled == true
    end

    test "accepts map config" do
      assert {:ok, config} = TableauRefLinkExtension.config(%{enabled: true})
      assert config.enabled == true
    end

    test "defaults enabled to true" do
      assert {:ok, config} = TableauRefLinkExtension.config(%{})
      assert config.enabled == true
    end

    test "defaults prefix to $ref:" do
      assert {:ok, config} = TableauRefLinkExtension.config(%{})
      assert config.prefix == "$ref:"
    end

    test "defaults site_prefix to $site:" do
      assert {:ok, config} = TableauRefLinkExtension.config(%{})
      assert config.site_prefix == "$site:"
    end

    test "normalizes prefix without colon" do
      assert {:ok, config} = TableauRefLinkExtension.config(%{prefix: "$ref"})
      assert config.prefix == "$ref:"
    end

    test "preserves prefix with colon" do
      assert {:ok, config} = TableauRefLinkExtension.config(%{prefix: "$ref:"})
      assert config.prefix == "$ref:"
    end

    test "normalizes site_prefix without colon" do
      assert {:ok, config} = TableauRefLinkExtension.config(%{site_prefix: "$site"})
      assert config.site_prefix == "$site:"
    end

    test "preserves site_prefix with colon" do
      assert {:ok, config} = TableauRefLinkExtension.config(%{site_prefix: "$site:"})
      assert config.site_prefix == "$site:"
    end

    test "handles nil prefix" do
      assert {:ok, config} = TableauRefLinkExtension.config(%{prefix: nil})
      assert config.prefix == "$ref:"
    end

    test "handles empty string prefix" do
      assert {:ok, config} = TableauRefLinkExtension.config(%{prefix: ""})
      assert config.prefix == "$ref:"
    end

    test "handles nil site_prefix" do
      assert {:ok, config} = TableauRefLinkExtension.config(%{site_prefix: nil})
      assert config.site_prefix == "$site:"
    end

    test "handles empty string site_prefix" do
      assert {:ok, config} = TableauRefLinkExtension.config(%{site_prefix: ""})
      assert config.site_prefix == "$site:"
    end

    test "handles invalid prefix types" do
      assert {:ok, config} = TableauRefLinkExtension.config(%{prefix: 123})
      assert config.prefix == "$ref:"
    end

    test "handles invalid site_prefix types" do
      assert {:ok, config} = TableauRefLinkExtension.config(%{site_prefix: [:invalid]})
      assert config.site_prefix == "$site:"
    end
  end

  describe "pre_build/1" do
    test "builds content map from posts and pages" do
      token =
        build_token(
          posts: [
            build_post("_posts/2024-01-15-first.md", "/posts/2024/01/15/first"),
            build_post("_posts/2024-01-20-second.md", "/posts/2024/01/20/second")
          ],
          pages: [
            build_page_item("about.md", "/about"),
            build_page_item("contact.md", "/contact")
          ]
        )

      {:ok, result} = TableauRefLinkExtension.pre_build(token)

      assert result.ref_links.content_map.by_path["_posts/2024-01-15-first.md"] == "/posts/2024/01/15/first"
      assert result.ref_links.content_map.by_path["about.md"] == "/about"
      assert result.ref_links.content_map.by_filename["about.md"] == ["/about"]
      assert result.ref_links.content_map.by_filename["2024-01-15-first.md"] == ["/posts/2024/01/15/first"]
    end

    test "handles ambiguous filenames" do
      token =
        build_token(
          pages: [
            build_page_item("about.md", "/about"),
            build_page_item("pages/about.md", "/pages/about"),
            build_page_item("docs/about.md", "/docs/about")
          ]
        )

      {:ok, result} = TableauRefLinkExtension.pre_build(token)

      # All three should be in by_filename under same key
      assert length(result.ref_links.content_map.by_filename["about.md"]) == 3
      assert "/about" in result.ref_links.content_map.by_filename["about.md"]
      assert "/pages/about" in result.ref_links.content_map.by_filename["about.md"]
      assert "/docs/about" in result.ref_links.content_map.by_filename["about.md"]

      # Each should have unique path entry
      assert result.ref_links.content_map.by_path["about.md"] == "/about"
      assert result.ref_links.content_map.by_path["pages/about.md"] == "/pages/about"
      assert result.ref_links.content_map.by_path["docs/about.md"] == "/docs/about"
    end

    test "extracts base URL path from site config" do
      token = build_token(site_config: %{url: "https://example.com/blog"})

      {:ok, result} = TableauRefLinkExtension.pre_build(token)

      assert result.ref_links.base_url_path == "/blog"
    end

    test "defaults base URL path to / for root URLs" do
      token = build_token(site_config: %{url: "https://example.com"})

      {:ok, result} = TableauRefLinkExtension.pre_build(token)

      assert result.ref_links.base_url_path == "/"
    end

    test "handles missing URL path in site config" do
      token = build_token(site_config: %{url: "https://example.com"})

      {:ok, result} = TableauRefLinkExtension.pre_build(token)

      assert result.ref_links.base_url_path == "/"
    end

    test "handles empty URL path" do
      token = build_token(site_config: %{url: "https://example.com/"})

      {:ok, result} = TableauRefLinkExtension.pre_build(token)

      assert result.ref_links.base_url_path == "/"
    end

    @tag :tmp_dir
    test "scans static assets from extra directory", %{tmp_dir: dir} do
      # Create extra directory with assets
      File.mkdir_p!(Path.join([dir, "extra/images"]))
      File.mkdir_p!(Path.join([dir, "extra/css"]))

      File.write!(Path.join([dir, "extra/images/photo.svg"]), "<svg></svg>")
      File.write!(Path.join([dir, "extra/css/style.css"]), "body {}")

      token = build_token(site_config: %{include_dir: Path.join(dir, "extra")})

      {:ok, result} = TableauRefLinkExtension.pre_build(token)

      # Static assets should be indexed by filename
      assert result.ref_links.content_map.by_filename["photo.svg"] == ["/images/photo.svg"]
      assert result.ref_links.content_map.by_filename["style.css"] == ["/css/style.css"]

      # And by path
      assert result.ref_links.content_map.by_path["images/photo.svg"] == "/images/photo.svg"
      assert result.ref_links.content_map.by_path["css/style.css"] == "/css/style.css"
    end

    @tag :tmp_dir
    test "content files take precedence over static assets with same filename", %{tmp_dir: dir} do
      # Create extra directory with asset that has same basename as content
      File.mkdir_p!(Path.join([dir, "extra"]))
      File.write!(Path.join([dir, "extra/test.md"]), "# Asset")

      token =
        build_token(
          pages: [build_page_item("test.md", "/content/test")],
          site_config: %{include_dir: Path.join(dir, "extra")}
        )

      {:ok, result} = TableauRefLinkExtension.pre_build(token)

      # Both should be in by_filename, with content first
      filenames = result.ref_links.content_map.by_filename["test.md"]
      assert length(filenames) == 2
      assert hd(filenames) == "/content/test"
      assert "/test.md" in filenames
    end
  end

  describe "full pipeline" do
    test "resolves filename references" do
      token =
        build_token(
          posts: [build_post("2024-01-15-post.md", "/posts/2024/01/15/post")],
          pages: [build_page_item("about.md", "/about")],
          page_bodies: [build_page(~s(<a href="$ref:2024-01-15-post.md">Link</a>), permalink: "/test")]
        )

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(href="/posts/2024/01/15/post")
      refute get_page_body(result) =~ "$ref:"
    end

    test "resolves path references" do
      token =
        build_token(
          pages: [build_page_item("pages/about.md", "/pages/about")],
          page_bodies: [build_page(~s(<a href="$ref:pages/about.md">About</a>), permalink: "/test")]
        )

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(href="/pages/about")
    end

    test "preserves anchors in references" do
      token =
        build_token(
          pages: [build_page_item("guide.md", "/guide")],
          page_bodies: [build_page(~s(<a href="$ref:guide.md#section">Guide Section</a>), permalink: "/test")]
        )

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(href="/guide#section")
    end

    test "resolves site references with root base path" do
      token =
        build_token(page_bodies: [build_page(~s(<a href="$site:downloads/file.pdf">Download</a>), permalink: "/test")])

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(href="/downloads/file.pdf")
    end

    test "resolves site references with non-root base path" do
      token =
        build_token(
          site_config: %{url: "https://example.com/blog"},
          page_bodies: [build_page(~s(<a href="$site:assets/style.css">Style</a>), permalink: "/test")]
        )

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(href="/blog/assets/style.css")
    end

    test "resolves content references with non-root base path" do
      token =
        build_token(
          posts: [build_post("2024-01-15-post.md", "/posts/2024/01/15/post")],
          site_config: %{url: "https://example.com/blog"},
          page_bodies: [build_page(~s(<a href="$ref:2024-01-15-post.md">Post</a>), permalink: "/test")]
        )

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(href="/blog/posts/2024/01/15/post")
    end

    test "preserves anchors in site references" do
      token =
        build_token(page_bodies: [build_page(~s(<link href="$site:docs/api.html#intro" />), permalink: "/test")])

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(href="/docs/api.html#intro")
    end

    test "handles missing references" do
      token =
        build_token(page_bodies: [build_page(~s(<a href="$ref:missing.md">Missing</a>), permalink: "/test")])

      log =
        capture_log(fn ->
          {:ok, result} = process_full_pipeline(token)
          assert get_page_body(result) =~ ~s(href="#ref-not-found:missing.md")
        end)

      assert log =~ "Reference not found: missing.md"
    end

    test "handles ambiguous references with warning" do
      token =
        build_token(
          pages: [
            build_page_item("about.md", "/about"),
            build_page_item("pages/about.md", "/pages/about")
          ],
          page_bodies: [build_page(~s(<a href="$ref:about.md">About</a>), permalink: "/test")]
        )

      log =
        capture_log(fn ->
          {:ok, result} = process_full_pipeline(token)
          # Should use first match
          body = get_page_body(result)
          assert body =~ ~s(href="/about") or body =~ ~s(href="/pages/about")
        end)

      assert log =~ "Ambiguous reference 'about.md' matches 2 files"
    end

    test "transforms multiple links in same page" do
      html = """
      <html>
        <body>
          <a href="$ref:about.md">About</a>
          <a href="$ref:contact.md">Contact</a>
          <a href="$site:assets/style.css">Style</a>
        </body>
      </html>
      """

      token =
        build_token(
          pages: [
            build_page_item("about.md", "/about"),
            build_page_item("contact.md", "/contact")
          ],
          page_bodies: [build_page(html, permalink: "/test")]
        )

      {:ok, result} = process_full_pipeline(token)
      body = get_page_body(result)

      assert body =~ ~s(href="/about")
      assert body =~ ~s(href="/contact")
      assert body =~ ~s(href="/assets/style.css")
      refute body =~ "$ref:"
      refute body =~ "$site:"
    end

    test "leaves non-reference links unchanged" do
      html = """
      <html>
        <body>
          <a href="https://example.com">External</a>
          <a href="/local/path">Local</a>
          <a href="#anchor">Anchor</a>
        </body>
      </html>
      """

      token = build_token(page_bodies: [build_page(html, permalink: "/test")])

      {:ok, result} = process_full_pipeline(token)
      body = get_page_body(result)

      assert body =~ ~s(href="https://example.com")
      assert body =~ ~s(href="/local/path")
      assert body =~ ~s(href="#anchor")
    end
  end

  describe "element type support" do
    test "transforms img src attributes" do
      token =
        build_token(
          pages: [build_page_item("photo.jpg", "/images/photo.jpg")],
          page_bodies: [build_page(~s(<img src="$ref:photo.jpg" alt="Photo" />), permalink: "/test")]
        )

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(src="/images/photo.jpg")
    end

    test "transforms video src attributes" do
      token =
        build_token(page_bodies: [build_page(~s(<video src="$site:videos/demo.mp4"></video>), permalink: "/test")])

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(src="/videos/demo.mp4")
    end

    test "transforms audio src attributes" do
      token =
        build_token(page_bodies: [build_page(~s(<audio src="$site:audio/track.mp3"></audio>), permalink: "/test")])

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(src="/audio/track.mp3")
    end

    test "transforms source src attributes" do
      token =
        build_token(page_bodies: [build_page(~s(<source src="$site:media/video.webm" />), permalink: "/test")])

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(src="/media/video.webm")
    end

    test "transforms track src attributes" do
      token =
        build_token(page_bodies: [build_page(~s(<track src="$site:captions/en.vtt" />), permalink: "/test")])

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(src="/captions/en.vtt")
    end

    test "transforms embed src attributes" do
      token =
        build_token(page_bodies: [build_page(~s(<embed src="$site:content/doc.pdf" />), permalink: "/test")])

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(src="/content/doc.pdf")
    end

    test "transforms iframe src attributes" do
      token =
        build_token(page_bodies: [build_page(~s(<iframe src="$site:embed/widget.html"></iframe>), permalink: "/test")])

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(src="/embed/widget.html")
    end

    test "transforms script src attributes" do
      token =
        build_token(page_bodies: [build_page(~s(<script src="$site:js/app.js"></script>), permalink: "/test")])

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(src="/js/app.js")
    end

    test "transforms link href attributes" do
      token =
        build_token(
          pages: [build_page_item("style.css", "/css/style.css")],
          page_bodies: [build_page(~s(<link rel="stylesheet" href="$ref:style.css" />), permalink: "/test")]
        )

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(href="/css/style.css")
    end

    test "transforms a href attributes" do
      token =
        build_token(
          pages: [build_page_item("about.md", "/about")],
          page_bodies: [build_page(~s(<a href="$ref:about.md">About</a>), permalink: "/test")]
        )

      {:ok, result} = process_full_pipeline(token)

      assert get_page_body(result) =~ ~s(href="/about")
    end

    test "ignores unsupported elements" do
      html = """
      <html>
        <body>
          <div data-ref="$ref:something">Content</div>
          <span>Text</span>
        </body>
      </html>
      """

      token = build_token(page_bodies: [build_page(html, permalink: "/test")])

      {:ok, result} = process_full_pipeline(token)
      body = get_page_body(result)

      # Should remain unchanged
      assert body =~ ~s(data-ref="$ref:something")
    end

    test "ignores elements without target attribute" do
      html = """
      <html>
        <body>
          <a>No href</a>
          <img alt="No src" />
        </body>
      </html>
      """

      token = build_token(page_bodies: [build_page(html, permalink: "/test")])

      {:ok, result} = process_full_pipeline(token)
      body = get_page_body(result)

      assert body =~ ~s(<a>No href</a>)
      assert body =~ ~s(<img alt="No src")
    end

    test "preserves text nodes and comments" do
      html = """
      <html>
        <body>
          Text content
          <!-- Comment -->
          <a href="$ref:about.md">Link</a>
        </body>
      </html>
      """

      token =
        build_token(
          pages: [build_page_item("about.md", "/about")],
          page_bodies: [build_page(html, permalink: "/test")]
        )

      {:ok, result} = process_full_pipeline(token)
      body = get_page_body(result)

      assert body =~ "Text content"
      assert body =~ "<!-- Comment -->"
    end
  end

  describe "media element transformation" do
    # Legacy tests - can be removed once coverage is verified
    test "transforms img src attributes with reference prefix" do
      content_map = %{
        by_path: %{},
        by_filename: %{"photo.jpg" => ["/images/photo.jpg"]}
      }

      html = """
      <html>
        <body>
          <img src="$ref:photo.jpg" alt="Photo" />
        </body>
      </html>
      """

      page = %{body: html, permalink: "/test/"}

      token = %{
        site: %{pages: [page]},
        extensions: %{
          ref_links: %{
            config: %{enabled: true, prefix: "$ref:", site_prefix: "$site:"}
          }
        },
        ref_links: %{
          content_map: content_map,
          base_url_path: "/"
        }
      }

      {:ok, result_token} = TableauRefLinkExtension.pre_write(token)
      [result_page] = result_token.site.pages

      assert result_page.body =~ ~s(src="/images/photo.jpg")
      refute result_page.body =~ "$ref:"
    end

    test "transforms video src attributes with site prefix" do
      html = """
      <html>
        <body>
          <video src="$site:videos/demo.mp4" controls></video>
        </body>
      </html>
      """

      page = %{body: html, permalink: "/test/"}

      token = %{
        site: %{pages: [page]},
        extensions: %{
          ref_links: %{
            config: %{enabled: true, prefix: "$ref:", site_prefix: "$site:"}
          }
        },
        ref_links: %{
          content_map: %{by_path: %{}, by_filename: %{}},
          base_url_path: "/"
        }
      }

      {:ok, result_token} = TableauRefLinkExtension.pre_write(token)
      [result_page] = result_token.site.pages

      assert result_page.body =~ ~s(src="/videos/demo.mp4")
      refute result_page.body =~ "$site:"
    end

    test "transforms link href attributes for stylesheets" do
      content_map = %{
        by_path: %{"css/custom.css" => "/css/custom.css"},
        by_filename: %{}
      }

      html = """
      <html>
        <head>
          <link rel="stylesheet" href="$ref:css/custom.css" />
        </head>
      </html>
      """

      page = %{body: html, permalink: "/test/"}

      token = %{
        site: %{pages: [page]},
        extensions: %{
          ref_links: %{
            config: %{enabled: true, prefix: "$ref:", site_prefix: "$site:"}
          }
        },
        ref_links: %{
          content_map: content_map,
          base_url_path: "/"
        }
      }

      {:ok, result_token} = TableauRefLinkExtension.pre_write(token)
      [result_page] = result_token.site.pages

      assert result_page.body =~ ~s(href="/css/custom.css")
      refute result_page.body =~ "$ref:"
    end
  end

  describe "logging" do
    test "logs warning when reference is not found" do
      pages = [
        build_page(
          file: "test.md",
          permalink: "/test",
          body: ~s(<a href="$ref:missing.md">Link</a>)
        )
      ]

      token = build_token(pages: pages)
      {:ok, token} = TableauRefLinkExtension.pre_build(token)

      log =
        capture_log(fn ->
          {:ok, result_token} = TableauRefLinkExtension.pre_write(token)
          result_page = hd(result_token.site.pages)
          assert result_page.body =~ "#ref-not-found:missing.md"
        end)

      assert log =~ "Reference not found: missing.md"
    end

    test "logs warning when path-based reference is not found" do
      pages = [
        build_page(
          file: "test.md",
          permalink: "/test",
          body: ~s(<a href="$ref:foo/missing.md">Link</a>)
        )
      ]

      token = build_token(pages: pages)
      {:ok, token} = TableauRefLinkExtension.pre_build(token)

      log =
        capture_log(fn ->
          {:ok, result_token} = TableauRefLinkExtension.pre_write(token)
          result_page = hd(result_token.site.pages)
          assert result_page.body =~ "#ref-not-found:foo/missing.md"
        end)

      assert log =~ "Reference not found: foo/missing.md"
    end

    test "logs warning with filenames when reference is ambiguous" do
      pages = [
        build_page(file: "_pages/first/test.md", permalink: "/first/test", body: "First"),
        build_page(file: "_pages/second/test.md", permalink: "/second/test", body: "Second"),
        build_page(
          file: "index.md",
          permalink: "/",
          body: ~s(<a href="$ref:test.md">Link</a>)
        )
      ]

      token = build_token(pages: pages)
      {:ok, token} = TableauRefLinkExtension.pre_build(token)

      log =
        capture_log(fn ->
          {:ok, result_token} = TableauRefLinkExtension.pre_write(token)
          result_page = Enum.find(result_token.site.pages, &(&1.permalink == "/"))
          # Should use first match
          assert result_page.body =~ ~s(href="/first/test")
        end)

      assert log =~ "Ambiguous reference 'test.md' matches 2 files"
      assert log =~ "/first/test, /second/test"
    end
  end
end
