defmodule Livedata.Registration do
  @moduledoc """
  Orchestrates developer project registration: validates the single form and
  creates a Project plus its Parcel atomically. (@req: KR 2.1)
  """
  alias Ecto.Multi
  alias Livedata.Repo
  alias Livedata.Geo.GeoJSON
  alias Livedata.Registration.Form
  alias Livedata.Projects.Project
  alias Livedata.ProjectParcels.ProjectParcel

  # Placeholder until operator auth lands; the column is nullable and set
  # programmatically (never cast from form input).
  @placeholder_operator_id "00000000-0000-0000-0000-000000000000"

  @spec register(map(), keyword()) ::
          {:ok, %{project: %Project{}, parcel: %ProjectParcel{}}} | {:error, Ecto.Changeset.t()}
  def register(attrs, opts \\ []) do
    operator_id = Keyword.get(opts, :operator_id, @placeholder_operator_id)
    form_changeset = Form.changeset(%Form{}, attrs)

    if form_changeset.valid? do
      form = Ecto.Changeset.apply_changes(form_changeset)
      commissioned_at = DateTime.utc_now()
      {:ok, project_boundary} = GeoJSON.decode_multipolygon(form.project_boundary_geojson)
      {:ok, parcel_boundary} = GeoJSON.decode_multipolygon(form.parcel_boundary_geojson)

      Multi.new()
      # @req: CRCF-21
      |> Multi.insert(:project, fn _changes ->
        %Project{}
        |> Project.changeset(%{
          name: form.project_name,
          description: form.project_description,
          spatial_boundary: project_boundary,
          commissioned_at: commissioned_at,
          status: "DRAFT"
        })
        |> Ecto.Changeset.put_change(:operator_id, operator_id)
      end)
      # @req: CRCF-36
      |> Multi.insert(:parcel, fn %{project: project} ->
        ProjectParcel.create_changeset(%ProjectParcel{}, project.id, %{
          parcel_ref: form.parcel_ref,
          data_source: form.parcel_data_source,
          boundary: parcel_boundary,
          commissioned_at: commissioned_at
        })
      end)
      |> Repo.transaction()
      |> case do
        {:ok, %{project: project, parcel: parcel}} ->
          {:ok, %{project: project, parcel: parcel}}

        # Return the Form changeset — not the DB changeset — so the LiveView can render
        # field-level errors using Form schema field names (project_name, parcel_ref, etc.).
        {:error, _step, _db_changeset, _changes} ->
          {:error, Map.put(form_changeset, :action, :validate)}
      end
    else
      {:error, Map.put(form_changeset, :action, :validate)}
    end
  end
end
