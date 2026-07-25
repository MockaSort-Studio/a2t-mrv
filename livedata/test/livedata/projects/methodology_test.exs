defmodule Livedata.Projects.MethodologyTest do
  use Livedata.DataCase, async: true

  alias Livedata.Projects
  alias Livedata.Projects.Methodology

  test "changeset requires name" do
    assert %{name: ["can't be blank"]} = errors_on(Methodology.changeset(%Methodology{}, %{}))
  end

  test "list_methodologies/0 returns methodologies ordered by name" do
    Repo.insert!(Methodology.changeset(%Methodology{}, %{name: "BioCCS"}))
    Repo.insert!(Methodology.changeset(%Methodology{}, %{name: "BCR"}))

    assert ["BCR", "BioCCS"] = Enum.map(Projects.list_methodologies(), & &1.name)
  end
end
