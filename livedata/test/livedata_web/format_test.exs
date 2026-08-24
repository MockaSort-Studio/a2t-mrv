defmodule LivedataWeb.FormatTest do
  use ExUnit.Case, async: true

  alias LivedataWeb.Format

  describe "relative_time/2" do
    test "returns 'never' for nil" do
      assert Format.relative_time(nil) == "never"
    end

    test "returns 'just now' for a timestamp within 60 seconds" do
      now = ~U[2026-08-01 12:00:00Z]
      assert Format.relative_time(DateTime.add(now, -0, :second), now) == "just now"
      assert Format.relative_time(DateTime.add(now, -30, :second), now) == "just now"
      assert Format.relative_time(DateTime.add(now, -59, :second), now) == "just now"
    end

    test "returns minutes ago for timestamps between 60 seconds and 1 hour" do
      now = ~U[2026-08-01 12:00:00Z]
      assert Format.relative_time(DateTime.add(now, -60, :second), now) == "1 min ago"
      assert Format.relative_time(DateTime.add(now, -120, :second), now) == "2 min ago"
      assert Format.relative_time(DateTime.add(now, -3599, :second), now) == "59 min ago"
    end

    test "returns hours ago for timestamps between 1 hour and 24 hours" do
      now = ~U[2026-08-01 12:00:00Z]
      assert Format.relative_time(DateTime.add(now, -1, :hour), now) == "1 h ago"
      assert Format.relative_time(DateTime.add(now, -3, :hour), now) == "3 h ago"
      assert Format.relative_time(DateTime.add(now, -23, :hour), now) == "23 h ago"
    end

    test "returns 'yesterday' for timestamps between 24 and 48 hours ago" do
      now = ~U[2026-08-01 12:00:00Z]
      assert Format.relative_time(DateTime.add(now, -24, :hour), now) == "yesterday"
      assert Format.relative_time(DateTime.add(now, -47, :hour), now) == "yesterday"
    end

    test "returns days ago for timestamps older than 48 hours" do
      now = ~U[2026-08-01 12:00:00Z]
      assert Format.relative_time(DateTime.add(now, -2, :day), now) == "2 days ago"
      assert Format.relative_time(DateTime.add(now, -5, :day), now) == "5 days ago"
    end

    test "returns 'in the future' for timestamps in the future" do
      now = ~U[2026-08-01 12:00:00Z]
      assert Format.relative_time(DateTime.add(now, 1, :second), now) == "in the future"
      assert Format.relative_time(DateTime.add(now, 30, :day), now) == "in the future"
    end
  end

  describe "period/2" do
    test "returns em dash when both dates are nil" do
      assert Format.period(nil, nil) == "—"
    end

    test "returns open-ended period when only start_date is given" do
      assert Format.period(~D[2026-01-01], nil) == "2026-01-01 → open-ended"
    end

    test "returns a closed period when both dates are given" do
      assert Format.period(~D[2026-01-01], ~D[2031-01-01]) == "2026-01-01 → 2031-01-01"
    end
  end

  describe "activity_type/1" do
    test "formats all known enum values" do
      assert Format.activity_type("PERMANENT_REMOVAL") == "Permanent removal"
      assert Format.activity_type("FARMING_SEQUESTRATION") == "Farming sequestration"
      assert Format.activity_type("PRODUCT_STORAGE") == "Product storage"
      assert Format.activity_type("SOIL_EMISSION_REDUCTION") == "Soil emission reduction"
    end

    test "returns the raw string for an unrecognised type (fallback branch)" do
      assert Format.activity_type("SOME_FUTURE_TYPE") == "SOME_FUTURE_TYPE"
    end

    test "returns em dash for nil" do
      assert Format.activity_type(nil) == "—"
    end
  end
end
