defmodule Site.HomePage do
  @moduledoc false

  use Tableau.Page,
    layout: Site.RootLayout,
    permalink: "/"

  import Temple

  def template(_assigns) do
    temple do
      p do
        "hello, world!"
      end
    end
  end
end
