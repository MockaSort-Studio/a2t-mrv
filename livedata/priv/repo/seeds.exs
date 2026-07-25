# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Livedata.Repo.insert!(%Livedata.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Livedata.Repo
alias Livedata.Projects.Methodology

# Placeholder registry entries (name + reference). The parametrised registry is #62.
unless Repo.exists?(Methodology) do
  for {name, reference} <- [
        {"DACCS", "Direct Air Carbon Capture and Storage"},
        {"BioCCS", "Bioenergy with Carbon Capture and Storage"},
        {"BCR", "Biochar Carbon Removal"},
        {"Carbon Farming", "CRCF carbon farming sequestration"},
        {"Carbon Storage in Products", "CRCF long-term product storage"}
      ] do
    Repo.insert!(Methodology.changeset(%Methodology{}, %{name: name, reference: reference}))
  end
end
