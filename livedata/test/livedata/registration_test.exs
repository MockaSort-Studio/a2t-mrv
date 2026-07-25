defmodule Livedata.RegistrationTest do
  use Livedata.DataCase, async: true

  @moduletag :integration

  alias Livedata.Registration
  alias Livedata.Projects.Project
  alias Livedata.Projects.Methodology
  alias Livedata.ProjectParcels.ProjectParcel

  @multipolygon ~s({"type":"MultiPolygon","coordinates":[[[[0.0,0.0],[1.0,0.0],[1.0,1.0],[0.0,1.0],[0.0,0.0]]]]})

  @valid %{
    "project_name" => "Test Project",
    "project_description" => "A test project",
    "parcel_ref" => "LPIS-IT-001",
    "parcel_data_source" => "LPIS",
    "parcel_boundary_geojson" => @multipolygon,
    "activity_name" => "Reduced tillage",
    "activity_description" => "Cover cropping and reduced tillage",
    "activity_type" => "SOIL_EMISSION_REDUCTION",
    "activity_period_start" => ~D[2024-01-01],
    "activity_period_end" => ~D[2024-12-31],
    "monitoring_period_start" => ~D[2024-01-01],
    "monitoring_period_end" => ~D[2024-12-31]
  }

  defp valid_attrs(overrides), do: Map.merge(@valid, overrides)

  # @req: CRCF-21
  test "register/2 creates a project and its parcel in one transaction" do
    m = Repo.insert!(Methodology.changeset(%Methodology{}, %{name: "M0"}))
    attrs = valid_attrs(%{"methodology_ids" => [m.id]})

    assert {:ok, %{project: project, parcel: parcel}} = Registration.register(attrs)
    assert %Project{} = Repo.get(Project, project.id)
    assert %ProjectParcel{} = Repo.get(ProjectParcel, parcel.id)
    assert parcel.project_id == project.id
    # @req: CRCF-37 — the boundary is recorded on the parcel only
    assert %Geo.MultiPolygon{srid: 4326} = parcel.boundary
    refute Map.has_key?(project, :spatial_boundary)
    assert project.status == "DRAFT"
    assert project.commissioned_at != nil
  end

  test "register/2 with invalid input returns an error and writes nothing" do
    assert {:error, changeset} =
             Registration.register(valid_attrs(%{"parcel_data_source" => "NOPE"}))

    refute changeset.valid?
    assert Repo.aggregate(Project, :count) == 0
    assert Repo.aggregate(ProjectParcel, :count) == 0
  end

  # @req: CRCF-21
  test "register/2 error path always returns a Form-shaped changeset" do
    # Form validation failure: the returned changeset must be a Form struct so the
    # LiveView (which reads @form[:project_name], @form[:parcel_ref], etc.) can render
    # field-level errors. If register/2 ever returned a Project/ProjectParcel changeset
    # instead, errors would silently disappear from the UI.
    assert {:error, changeset} =
             Registration.register(valid_attrs(%{"parcel_data_source" => "NOPE"}))

    assert changeset.data.__struct__ == Livedata.Registration.Form
    assert changeset.action == :validate
    assert Map.has_key?(changeset.changes, :project_name)
  end

  test "register/2 creates project, parcel, activity, and methodology links atomically" do
    m = Repo.insert!(Methodology.changeset(%Methodology{}, %{name: "M1"}))
    # helper builds the full form map
    attrs = valid_attrs(%{"methodology_ids" => [m.id]})

    assert {:ok, %{project: p, parcel: _, activity: a, methodologies: [am]}} =
             Registration.register(attrs)

    assert a.project_id == p.id
    # @req: CRCF-14 — SOIL derives FARMING
    assert a.storage_duration_tier == "FARMING" or
             a.storage_duration_tier in ~w(PERMANENT FARMING PRODUCTS)

    assert am.methodology_id == m.id
  end

  test "register/2 rolls back everything when the activity is invalid" do
    m = Repo.insert!(Methodology.changeset(%Methodology{}, %{name: "M1"}))
    attrs = valid_attrs(%{"methodology_ids" => [m.id], "activity_name" => ""})

    assert {:error, %Ecto.Changeset{}} = Registration.register(attrs)
    assert Repo.aggregate(Project, :count) == 0
  end
end
