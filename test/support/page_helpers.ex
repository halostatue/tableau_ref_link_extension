defmodule TableauRefLinkExtension.PageHelpers do
  @moduledoc false

  def build_token(opts \\ []) do
    posts = Keyword.get(opts, :posts, [])
    pages = Keyword.get(opts, :pages, [])
    page_bodies = Keyword.get(opts, :page_bodies, pages)
    site_config = Keyword.get(opts, :site_config, %{})
    config = Keyword.get(opts, :config, %{})

    default_site_config = %{url: "http://localhost:4999", include_dir: "extra"}

    %{
      posts: posts,
      pages: pages,
      site: %{
        config: Map.merge(default_site_config, site_config),
        pages: page_bodies
      },
      extensions: %{
        ref_links: %{
          config: build_config(config)
        }
      }
    }
  end

  def build_config(opts \\ %{}) do
    {:ok, config} = TableauRefLinkExtension.config(opts)
    config
  end

  def build_page(opts) when is_list(opts) do
    %{
      file: Keyword.fetch!(opts, :file),
      permalink: Keyword.fetch!(opts, :permalink),
      body: Keyword.get(opts, :body, "")
    }
  end

  def build_page(body, opts) when is_binary(body) do
    %{
      file: Keyword.get(opts, :file, "test.md"),
      body: body,
      permalink: Keyword.get(opts, :permalink, "/test")
    }
  end

  def build_post(file, permalink) do
    %{file: file, permalink: permalink}
  end

  def build_page_item(file, permalink) do
    %{file: file, permalink: permalink}
  end

  def process_full_pipeline(token) do
    with {:ok, token} <- TableauRefLinkExtension.pre_build(token) do
      TableauRefLinkExtension.pre_write(token)
    end
  end

  def get_page_body(token, index \\ 0) do
    token.site.pages
    |> Enum.at(index)
    |> Map.get(:body)
  end
end
