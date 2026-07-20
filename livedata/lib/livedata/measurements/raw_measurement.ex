defmodule Livedata.Measurements.RawMeasurement do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_source_types ~w(MANUAL_ENTRY REMOTE_SENSING MODEL_OUTPUT)

  # @req: CRCF-19
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "raw_measurements" do
    # @req: CRCF-21
    field :activity_id, :binary_id
    # @req: CRCF-20
    field :measured_at, :utc_datetime_usec
    # @req: CRCF-04
    field :source_type, :string
    # @req: CRCF-28
    field :content_hash, :string
    # @req: CRCF-04, CRCF-07
    field :provenance, :map
    # @req: CRCF-27
    field :values, :map
    # @req: CRCF-26
    field :is_superseded, :boolean, default: false
    # @req: CRCF-26
    field :superseded_by, :binary_id
    # @req: CRCF-20
    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  @doc false
  def changeset(raw_measurement, activity_id, attrs) do
    raw_measurement
    |> cast(attrs, [
      :measured_at,
      :source_type,
      :content_hash,
      :provenance,
      :values,
      :is_superseded,
      :superseded_by
    ])
    |> put_change(:activity_id, activity_id)
    |> validate_required([
      :activity_id,
      :measured_at,
      :source_type,
      :content_hash,
      :provenance,
      :values
    ])
    |> validate_inclusion(:source_type, @valid_source_types)
    |> validate_supersession()
    |> unique_constraint(:content_hash,
      name: :raw_measurements_content_hash_measured_at_index,
      message: "has already been taken"
    )
    |> foreign_key_constraint(:activity_id)
  end

  defp validate_supersession(changeset) do
    is_superseded = get_field(changeset, :is_superseded)
    superseded_by = get_field(changeset, :superseded_by)
    current_id = get_field(changeset, :id)

    changeset
    |> then(fn cs ->
      if is_superseded && is_nil(superseded_by) do
        add_error(cs, :superseded_by, "must be set when is_superseded is true")
      else
        cs
      end
    end)
    |> then(fn cs ->
      if !is_nil(superseded_by) && superseded_by == current_id do
        add_error(cs, :superseded_by, "cannot reference itself")
      else
        cs
      end
    end)
  end
end
