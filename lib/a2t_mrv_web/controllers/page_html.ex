defmodule A2tMrvWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use A2tMrvWeb, :html

  embed_templates "page_html/*"
end
