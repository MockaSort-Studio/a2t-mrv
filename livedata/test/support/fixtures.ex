defmodule Livedata.Fixtures do
  @moduledoc """
  Shared inserts for the `Project → Activity → Measurement` hierarchy
  (@req: CRCF-21). Kept in one place so the dashboard, monitoring and
  measurement suites all build the same shapes.
  """

  alias Livedata.Measurements
  alias Livedata.ProjectParcels.ProjectParcel
  alias Livedata.Projects.{Activity, Methodology, Project}
  alias Livedata.Repo

  @boundary %Geo.MultiPolygon{
    coordinates: [[[{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 1.0}, {0.0, 0.0}]]],
    srid: 4326
  }

  def boundary, do: @boundary

  @doc """
  Inserts a methodology. The registry is populated by `priv/repo/seeds.exs` in
  every real environment, so forms that offer a methodology picker (@req:
  CRCF-35) render it only when at least one row exists — tests that exercise
  the picker have to seed one themselves.
  """
  def methodology_fixture(attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          name: "Methodology #{System.unique_integer([:positive])}",
          reference: "CRCF test methodology"
        },
        Map.new(attrs)
      )

    %Methodology{} |> Methodology.changeset(attrs) |> Repo.insert!()
  end

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

  @doc """
  A `PERMANENT_REMOVAL` activity by default — its monitoring window is
  open-ended, so it is always inside the window unless a test says otherwise.
  """
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

  @doc """
  Inserts a raw measurement through the context, so `content_hash` dedup and
  provenance validation apply exactly as they do in the app.
  """
  def measurement_fixture(activity_id, measured_at \\ DateTime.utc_now(), values \\ nil) do
    values = values || %{"soc" => System.unique_integer([:positive]) / 1}

    {:ok, measurement} =
      Measurements.create_raw_measurement(%{
        "activity_id" => activity_id,
        "measured_at" => DateTime.to_iso8601(measured_at),
        "method" => "core",
        "latitude" => "45.1",
        "longitude" => "7.6",
        "crs" => "EPSG:4326",
        "values_json" => Jason.encode!(values)
      })

    measurement
  end
end
