defmodule Livedata.Measurements.Entry do
  @moduledoc """
  Embedded schema backing the manual measurement-entry form. Owns form-level
  validation, including JSON parsing of provenance and values, before the
  values are mapped onto RawMeasurement in `Livedata.Measurements`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  # @req: CRCF-16 — localization provenance (coordinates + projection); acquisition date is measured_at
  @required_provenance_keys ~w(method latitude longitude crs)
  @fields ~w(activity_id measured_at provenance_json values_json)a

  @primary_key false
  embedded_schema do
    field :activity_id, :binary_id
    field :measured_at, :utc_datetime_usec
    field :provenance_json, :string
    field :values_json, :string
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    # @req: CRCF-04, CRCF-07 — provenance validated first
    |> validate_provenance(:provenance_json)
    # @req: CRCF-27 — then values
    |> validate_values(:values_json)
  end

  defp validate_provenance(changeset, field) do
    validate_json_object(changeset, field, fn map ->
      missing = @required_provenance_keys -- Map.keys(map)

      if missing == [],
        do: :ok,
        else: {:error, "is missing required keys: #{Enum.join(missing, ", ")}"}
    end)
  end

  defp validate_values(changeset, field) do
    validate_json_object(changeset, field, fn map ->
      if map_size(map) >= 1, do: :ok, else: {:error, "must contain at least one value"}
    end)
  end

  # Decodes the field to a JSON object and runs `check`, adding a field error on failure.
  defp validate_json_object(changeset, field, check) do
    case get_field(changeset, field) do
      nil ->
        changeset

      value ->
        case Jason.decode(value) do
          {:ok, map} when is_map(map) ->
            case check.(map) do
              :ok -> changeset
              {:error, msg} -> add_error(changeset, field, msg)
            end

          {:ok, _not_a_map} ->
            add_error(changeset, field, "must be a JSON object")

          {:error, _} ->
            add_error(changeset, field, "is not valid JSON")
        end
    end
  end
end
