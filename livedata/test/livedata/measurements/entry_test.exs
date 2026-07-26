defmodule Livedata.Measurements.EntryTest do
  use ExUnit.Case, async: true
  import Livedata.DataCase, only: [errors_on: 1]

  alias Livedata.Measurements.Entry

  @valid %{
    "activity_id" => Ecto.UUID.generate(),
    "measured_at" => "2026-07-01T10:00:00Z",
    "provenance_json" =>
      ~s({"method":"core sample","latitude":45.1,"longitude":7.6,"crs":"EPSG:4326"}),
    "values_json" => ~s({"soil_organic_carbon":2.3,"unit":"pct"})
  }

  test "valid entry" do
    assert Entry.changeset(%Entry{}, @valid).valid?
  end

  test "required fields" do
    errors = errors_on(Entry.changeset(%Entry{}, %{}))
    for f <- [:activity_id, :measured_at, :provenance_json, :values_json], do: assert(errors[f])
  end

  test "provenance must be valid JSON" do
    cs = Entry.changeset(%Entry{}, %{@valid | "provenance_json" => "{not json"})
    assert %{provenance_json: ["is not valid JSON"]} = errors_on(cs)
  end

  test "provenance must be a JSON object" do
    cs = Entry.changeset(%Entry{}, %{@valid | "provenance_json" => "[1,2]"})
    assert %{provenance_json: ["must be a JSON object"]} = errors_on(cs)
  end

  test "provenance must contain required keys" do
    cs = Entry.changeset(%Entry{}, %{@valid | "provenance_json" => ~s({"method":"x"})})
    assert %{provenance_json: [msg]} = errors_on(cs)
    assert msg =~ "missing required keys"
  end

  test "values must be a non-empty JSON object" do
    cs = Entry.changeset(%Entry{}, %{@valid | "values_json" => "{}"})
    assert %{values_json: ["must contain at least one value"]} = errors_on(cs)
  end
end
