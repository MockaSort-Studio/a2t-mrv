defmodule Livedata.Fixtures do
  @moduledoc """
  Shared inserts for the Project → Activity → Measurement hierarchy (@req: CRCF-21).
  Suites that insert raw measurements must use `async: false` (hypertable).
  """

  alias Livedata.Measurements
  alias Livedata.ProjectParcels.ProjectParcel
  alias Livedata.Projects.{Activity, Project}
  alias Livedata.Repo

  @boundary %Geo.MultiPolygon{
    coordinates: [[[{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 1.0}, {0.0, 0.0}]]],
    srid: 4326
  }

  def boundary, do: @boundary

  def project_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          name: "Project #{System.unique_integer([:positive])}",
          commissioned_at: DateTime.utc_now()
        },
        Map.new(attrs)
      )

    %Project{} |> Project.changeset(attrs) |> Repo.insert!()
  end

  def parcel_fixture(project_id, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          parcel_ref: "LPIS-#{System.unique_integer([:positive])}",
          data_source: "LPIS",
          boundary: @boundary,
          commissioned_at: DateTime.utc_now()
        },
        Map.new(attrs)
      )

    %ProjectParcel{} |> ProjectParcel.create_changeset(project_id, attrs) |> Repo.insert!()
  end

  @doc "PERMANENT_REMOVAL activity (open-ended window) by default; override via attrs."
  def activity_fixture(project_id, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          name: "Activity #{System.unique_integer([:positive])}",
          activity_type: "PERMANENT_REMOVAL",
          status: "REGISTERED",
          activity_period_start: ~D[2026-01-01],
          monitoring_period_start: ~D[2025-12-01]
        },
        Map.new(attrs)
      )

    %Activity{} |> Activity.changeset(project_id, attrs) |> Repo.insert!()
  end

  @doc "A project with one parcel and one activity, for dashboard-shaped tests."
  def portfolio_fixture(opts \\ []) do
    project = project_fixture(Keyword.get(opts, :project, %{}))
    parcel = parcel_fixture(project.id, Keyword.get(opts, :parcel, %{}))
    activity = activity_fixture(project.id, Keyword.get(opts, :activity, %{}))
    %{project: project, parcel: parcel, activity: activity}
  end

  @doc "Inserts a raw measurement through the context (dedup + provenance apply)."
  def measurement_fixture(activity_id, measured_at \\ DateTime.utc_now(), values \\ nil) do
    values = values || %{"soc" => System.unique_integer([:positive]) / 1}

    {:ok, measurement} =
      Measurements.create_raw_measurement(%{
        "activity_id" => activity_id,
        "measured_at" => DateTime.to_iso8601(measured_at),
        "provenance_json" =>
          ~s({"method":"core","latitude":45.1,"longitude":7.6,"crs":"EPSG:4326"}),
        "values_json" => Jason.encode!(values)
      })

    measurement
  end
end
