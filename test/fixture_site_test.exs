defmodule TableauRefLinkExtension.FixtureSiteTest do
  use ExUnit.Case

  @moduletag :fixture_site
  @moduletag timeout: 60_000

  @site_output Path.expand("fixtures/_site", __DIR__)

  setup_all do
    File.rm_rf!(@site_output)
    TableauRefLinkExtension.FixtureBuilder.build()
    :ok
  end

  describe "full Tableau build with ref_link extension" do
    test "resolves cross-references between posts" do
      first_post = read_output("posts/2024/01/15/first-post/index.html")
      second_post = read_output("posts/2024/01/20/second-post/index.html")

      # First post should link to second post
      assert first_post =~ ~s(href="/base/posts/2024/01/20/second-post")
      refute first_post =~ "$ref:"

      # Second post should link to first post
      assert second_post =~ ~s(href="/base/posts/2024/01/15/first-post")
      refute second_post =~ "$ref:"
    end

    test "resolves references to pages" do
      first_post = read_output("posts/2024/01/15/first-post/index.html")

      # Should link to about page
      assert first_post =~ ~s(href="/base/about")
    end

    test "resolves references to static assets" do
      second_post = read_output("posts/2024/01/20/second-post/index.html")

      # Should link to SVG in extra directory
      assert second_post =~ ~s(src="/base/test-image.svg")
      refute second_post =~ "$ref:test-image.svg"
    end

    test "resolves site references" do
      about_page = read_output("about/index.html")

      # Should resolve $site: reference
      assert about_page =~ ~s(href="/base/posts/index.html")
      refute about_page =~ "$site:"
    end

    test "resolves references in HTML attributes" do
      about_page = read_output("about/index.html")

      # Link tag should have resolved reference
      assert about_page =~ ~s(<link rel="stylesheet" href="/base/css/style.css")
      refute about_page =~ "$ref:style.css"
    end

    test "static assets are copied to output" do
      # Verify static assets exist in output
      assert File.exists?(Path.join(@site_output, "test-image.svg"))
      assert File.exists?(Path.join(@site_output, "css/style.css"))
    end
  end

  defp read_output(path) do
    @site_output
    |> Path.join(path)
    |> File.read!()
  end
end
