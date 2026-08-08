defmodule Livedata.Measurements.Entry do
  @moduledoc """
  Embedded schema backing the manual measurement-entry form. Owns form-level
  validation before the values are mapped onto RawMeasurement in
  `Livedata.Measurements`.

  ## Why provenance is structured, not JSON

  CRCF-16 requires every localization record to carry coordinates, a
  georeferencing projection and an acquisition date. Asking a developer in the
  field to hand-write a JSON object containing exactly `method`, `latitude`,
  `longitude` and `crs` makes complete provenance a matter of luck; making
  them four typed fields makes it structural. Anything source-specific beyond
  those four goes in `extra_provenance_json` and is merged underneath them —
  the required keys always win, so they can never be overwritten by accident.

  `values` stays free-form JSON (via `values_json` or the key/value pairs the
  form collects) until monitoring templates arrive with the methodology
  engine (#62) and define its shape per methodology. (@req: CRCF-04, CRCF-07)
  """
  use Ecto.Schema
  import Ecto.Changeset

  # @req: CRCF-16 — coordinates + projection; the acquisition date is measured_at.
  @required_provenance_keys ~w(method latitude longitude crs)

  @fields ~w(activity_id measured_at method latitude longitude crs
             extra_provenance_json values_json)a
  @required ~w(activity_id measured_at method latitude longitude crs values_json)a

  @default_crs "EPSG:4326"

  @doc "Coordinate reference systems offered by the form. WGS84 is the default."
  def crs_options, do: [@default_crs, "EPSG:3035", "EPSG:25832", "EPSG:27700"]

  def default_crs, do: @default_crs

  def required_provenance_keys, do: @required_provenance_keys

  @primary_key false
  embedded_schema do
    field :activity_id, :binary_id
    field :measured_at, :utc_datetime_usec
    # @req: CRCF-16
    field :method, :string
    field :latitude, :float
    field :longitude, :float
    field :crs, :string, default: @default_crs
    field :extra_provenance_json, :string
    field :values_json, :string
  end

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, @fields)
    |> validate_required(@required)
    # @req: CRCF-16 — provenance validated first, then values.
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_json_object(:extra_provenance_json)
    # @req: CRCF-27
    |> validate_values(:values_json)
  end

  @doc """
  The provenance map to persist: the four required keys, plus anything the
  developer added, which can never displace them. (@req: CRCF-16)
  """
  @spec provenance(%__MODULE__{}) :: map()
  def provenance(%__MODULE__{} = entry) do
    extra =
      case entry.extra_provenance_json do
        blank when blank in [nil, ""] -> %{}
        json -> Jason.decode!(json)
      end

    Map.merge(extra, %{
      "method" => entry.method,
      "latitude" => entry.latitude,
      "longitude" => entry.longitude,
      "crs" => entry.crs
    })
  end

  @doc "The decoded measurement payload."
  @spec values(%__MODULE__{}) :: map()
  def values(%__MODULE__{values_json: values_json}), do: Jason.decode!(values_json)

  defp validate_values(changeset, field) do
    validate_json_object(changeset, field, fn map ->
      if map_size(map) >= 1, do: :ok, else: {:error, "must contain at least one value"}
    end)
  end

  # Decodes the field to a JSON object and runs `check`, adding a field error on
  # failure. A blank optional field is left alone. (@req: CRCF-38)
  defp validate_json_object(changeset, field, check \\ fn _map -> :ok end) do
    case get_field(changeset, field) do
      blank when blank in [nil, ""] ->
        changeset

      value ->
        case Jason.decode(value) do
          {:ok, map} when is_map(map) ->
            case check.(map) do
              :ok -> changeset
              {:error, message} -> add_error(changeset, field, message)
            end

          {:ok, _not_a_map} ->
            add_error(changeset, field, "must be a JSON object")

          {:error, _reason} ->
            add_error(changeset, field, "is not valid JSON")
        end
    end
  end
end
