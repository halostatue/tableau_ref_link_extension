defmodule Site.RootLayout do
  @moduledoc false
  use Tableau.Layout

  import Temple

  def template(assigns) do
    temple do
      "<!DOCTYPE html>"

      html lang: "end" do
        head do
          meta(charset: "utf-8")
          meta(http_equiv: "X-UA-Compatible", content: "IE=edge")
          meta(name: "viewport", content: "width=device-width, initial-scale=1.0")

          title do
            [@page[:title], "site"]
            |> Enum.filter(& &1)
            |> Enum.intersperse("|")
            |> Enum.join(" ")
          end

          link(rel: "stylesheet", href: "/css/site.css")
          script(src: "/js/site.js")
        end

        body do
          main do
            render(@inner_content)
          end
        end
      end
    end
  end
end
