defmodule Site.PostLayout do
  @moduledoc false
  use Tableau.Layout

  import Temple

  def template(assigns) do
    temple do
      "<!DOCTYPE html>"

      html do
        head do
          title(do: @page.title)
        end

        body do
          article do
            render(@inner_content)
          end
        end
      end
    end
  end
end
