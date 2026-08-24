defmodule LivedataWeb.FormatTest do
  use ExUnit.Case, async: true

  alias LivedataWeb.Format

  @now ~U[2026-08-01 12:00:00Z]

  describe "relative_time/2" do
    test "nil returns never" do
      assert Format.relative_time(nil) == "never"
    end

    test "boundaries: future / just-now / min / h / yesterday / days" do
      assert Format.relative_time(DateTime.add(@now, 1, :second), @now) == "in the future"
      assert Format.relative_time(@now, @now) == "just now"
      assert Format.relative_time(DateTime.add(@now, -59, :second), @now) == "just now"
      assert Format.relative_time(DateTime.add(@now, -60, :second), @now) == "1 min ago"
      assert Format.relative_time(DateTime.add(@now, -3599, :second), @now) == "59 min ago"
      assert Format.relative_time(DateTime.add(@now, -1, :hour), @now) == "1 h ago"
      assert Format.relative_time(DateTime.add(@now, -23, :hour), @now) == "23 h ago"
      assert Format.relative_time(DateTime.add(@now, -24, :hour), @now) == "yesterday"
      assert Format.relative_time(DateTime.add(@now, -47, :hour), @now) == "yesterday"
      assert Format.relative_time(DateTime.add(@now, -2, :day), @now) == "2 days ago"
    end
  end

  describe "period/2" do
    test "nil/nil, open-ended, and closed" do
      assert Format.period(nil, nil) == "—"
      assert Format.period(~D[2026-01-01], nil) == "2026-01-01 → open-ended"
      assert Format.period(~D[2026-01-01], ~D[2031-01-01]) == "2026-01-01 → 2031-01-01"
    end
  end

  describe "activity_type/1" do
    test "all known values, unknown fallback, and nil" do
      assert Format.activity_type("PERMANENT_REMOVAL") == "Permanent removal"
      assert Format.activity_type("FARMING_SEQUESTRATION") == "Farming sequestration"
      assert Format.activity_type("PRODUCT_STORAGE") == "Product storage"
      assert Format.activity_type("SOIL_EMISSION_REDUCTION") == "Soil emission reduction"
      assert Format.activity_type("SOME_FUTURE_TYPE") == "SOME_FUTURE_TYPE"
      assert Format.activity_type(nil) == "—"
    end
  end
end
