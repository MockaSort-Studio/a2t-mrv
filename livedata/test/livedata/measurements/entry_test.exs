defmodule Livedata.Measurements.EntryTest do
  use ExUnit.Case, async: true
  import Livedata.DataCase, only: [errors_on: 1]

  alias Livedata.Measurements.Entry

  @valid %{
    "activity_id" => Ecto.UUID.generate(),
    "measured_at" => "2026-07-01T10:00:00Z",
    "method" => "core sample",
    "latitude" => "45.1",
    "longitude" => "7.6",
    "crs" => "EPSG:4326",
    "values_json" => ~s({"soil_organic_carbon":2.3,"unit":"pct"})
  }

  test "valid entry" do
    assert Entry.changeset(%Entry{}, @valid).valid?
  end

  # @req: CRCF-16 — provenance is required field by field, not as free text.
  test "required fields" do
    errors = errors_on(Entry.changeset(%Entry{}, %{}))

    for field <- [:activity_id, :measured_at, :method, :latitude, :longitude, :values_json] do
      assert errors[field], "expected #{field} to be required"
    end
  end

  test "crs defaults to WGS84" do
    entry = Ecto.Changeset.apply_changes(Entry.changeset(%Entry{}, Map.delete(@valid, "crs")))
    assert entry.crs == "EPSG:4326"
  end

  test "latitude and longitude must be on the globe" do
    assert %{latitude: [_]} = errors_on(Entry.changeset(%Entry{}, %{@valid | "latitude" => "91"}))

    assert %{longitude: [_]} =
             errors_on(Entry.changeset(%Entry{}, %{@valid | "longitude" => "181"}))

    assert %{latitude: [_]} =
             errors_on(Entry.changeset(%Entry{}, %{@valid | "latitude" => "-90.5"}))
  end

  test "values must be a non-empty JSON object" do
    cs = Entry.changeset(%Entry{}, %{@valid | "values_json" => "{}"})
    assert %{values_json: ["must contain at least one value"]} = errors_on(cs)
  end

  test "values must be valid JSON" do
    cs = Entry.changeset(%Entry{}, %{@valid | "values_json" => "{not json"})
    assert %{values_json: ["is not valid JSON"]} = errors_on(cs)
  end

  test "values must be an object, not an array" do
    cs = Entry.changeset(%Entry{}, %{@valid | "values_json" => "[1,2]"})
    assert %{values_json: ["must be a JSON object"]} = errors_on(cs)
  end

  describe "extra provenance" do
    test "is optional" do
      assert Entry.changeset(%Entry{}, Map.put(@valid, "extra_provenance_json", "")).valid?
    end

    test "must be a valid JSON object when present" do
      cs = Entry.changeset(%Entry{}, Map.put(@valid, "extra_provenance_json", "{nope"))
      assert %{extra_provenance_json: ["is not valid JSON"]} = errors_on(cs)

      cs = Entry.changeset(%Entry{}, Map.put(@valid, "extra_provenance_json", "[1]"))
      assert %{extra_provenance_json: ["must be a JSON object"]} = errors_on(cs)
    end
  end

  describe "provenance/1" do
    # @req: CRCF-16
    test "always carries the four required keys" do
      entry = Ecto.Changeset.apply_changes(Entry.changeset(%Entry{}, @valid))
      provenance = Entry.provenance(entry)

      assert Map.keys(provenance) |> Enum.sort() ==
               Enum.sort(Entry.required_provenance_keys())

      assert provenance["method"] == "core sample"
      assert provenance["latitude"] == 45.1
      assert provenance["crs"] == "EPSG:4326"
    end

    test "merges extra provenance underneath the required keys" do
      attrs =
        Map.put(
          @valid,
          "extra_provenance_json",
          ~s({"instrument":"probe-7","method":"tampered"})
        )

      entry = Ecto.Changeset.apply_changes(Entry.changeset(%Entry{}, attrs))
      provenance = Entry.provenance(entry)

      assert provenance["instrument"] == "probe-7"
      # The typed field wins — extras can add, never overwrite.
      assert provenance["method"] == "core sample"
    end
  end

  test "values/1 decodes the payload" do
    entry = Ecto.Changeset.apply_changes(Entry.changeset(%Entry{}, @valid))
    assert Entry.values(entry) == %{"soil_organic_carbon" => 2.3, "unit" => "pct"}
  end
end
