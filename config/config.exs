import Config

if config_env() == :test do
  config :elixir, :time_zone_database, Tz.TimeZoneDatabase

  config :tableau, Tableau.PageExtension,
    enabled: true,
    dir: ["test/fixtures/_pages"],
    layout: Site.PageLayout

  config :tableau, Tableau.PostExtension,
    enabled: true,
    future: false,
    dir: ["test/fixtures/_posts"],
    layout: Site.PostLayout

  config :tableau, TableauRefLinkExtension, enabled: true

  config :tableau, :config,
    url: "https://example.com/base",
    include_dir: "test/fixtures/extra",
    out_dir: "test/fixtures/_site",
    markdown: [
      mdex: [
        extension: [
          table: true,
          header_ids: "",
          tasklist: true,
          strikethrough: true,
          autolink: true,
          alerts: true,
          footnotes: true
        ],
        render: [unsafe: true],
        syntax_highlight: [formatter: {:html_inline, theme: "neovim_dark"}]
      ]
    ]

  config :temple,
    engine: EEx.SmartEngine,
    attributes: {Temple, :attributes}
end
