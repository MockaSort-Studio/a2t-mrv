defmodule Livedata.Measurements.CsvParser do
  @moduledoc """
  Parses raw CSV text into row attribute maps for bulk measurement import.

  CSV column contract: measured_at, method, latitude, longitude, crs, values_json
  `crs` is optional (defaults to EPSG:4326). Quoted fields (RFC 4180) are
  supported — values_json typically contains commas and must be quoted.
  Embedded newlines inside quoted fields are NOT supported; the parser splits
  on newlines before field parsing.

  Returns `{:ok, [row_map]}` where each map carries a `"_row"` key (1-based),
  or `{:error, reason}` for structural failures.
  """

  @required_columns ~w(measured_at method latitude longitude values_json)
  @default_crs "EPSG:4326"

  @spec parse(String.t()) ::
          {:ok, [map()]}
          | {:error, :empty_file | :invalid_header | :no_data_rows}
  def parse(csv) when is_binary(csv) do
    csv = String.replace_prefix(csv, "﻿", "")
    lines = csv |> String.trim() |> split_lines()

    with {:ok, [header_line | data_lines]} <- require_non_empty(lines),
         {:ok, columns} <- parse_header(header_line),
         {:ok, data_lines} <- require_data(data_lines) do
      {:ok, data_lines |> Enum.with_index(1) |> Enum.map(&to_row(&1, columns))}
    end
  end

  defp split_lines(""), do: []
  defp split_lines(csv), do: String.split(csv, ~r/\r?\n/, trim: true)

  defp require_non_empty([]), do: {:error, :empty_file}
  defp require_non_empty(rows), do: {:ok, rows}

  defp require_data([]), do: {:error, :no_data_rows}
  defp require_data(lines), do: {:ok, lines}

  defp parse_header(line) do
    columns = line |> parse_fields() |> Enum.map(&String.trim/1)
    missing = @required_columns -- columns
    if missing == [], do: {:ok, columns}, else: {:error, :invalid_header}
  end

  defp to_row({line, index}, columns) do
    values = line |> parse_fields() |> Enum.map(&String.trim/1)

    columns
    |> Enum.zip(values)
    |> Map.new()
    |> default_crs()
    |> Map.put("_row", index)
  end

  defp default_crs(row) do
    case Map.get(row, "crs", "") do
      "" -> Map.put(row, "crs", @default_crs)
      _ -> row
    end
  end

  # RFC 4180 field parser: handles quoted fields with embedded commas.
  @spec parse_fields(String.t()) :: [String.t()]
  def parse_fields(line), do: do_parse(line, [], "")

  defp do_parse("", acc, current), do: Enum.reverse([current | acc])

  defp do_parse(<<",", rest::binary>>, acc, current),
    do: do_parse(rest, [current | acc], "")

  # A quote opens a quoted field only at the start of one. Leading whitespace is
  # padding, not content, so `a, "b,c"` quotes as intended — the form documents
  # the contract with spaces after each comma. Elsewhere a quote is a literal.
  defp do_parse(<<"\"", rest::binary>>, acc, current) do
    if String.trim(current) == "" do
      parse_quoted(rest, acc, "")
    else
      do_parse(rest, acc, current <> "\"")
    end
  end

  defp do_parse(<<char::utf8, rest::binary>>, acc, current),
    do: do_parse(rest, acc, current <> <<char::utf8>>)

  defp parse_quoted("", acc, current), do: Enum.reverse([current | acc])

  # RFC 4180: doubled quote → literal quote
  defp parse_quoted(<<"\"\"", rest::binary>>, acc, current),
    do: parse_quoted(rest, acc, current <> "\"")

  # Lenient: backslash-escaped quote (common in JSON-in-CSV exports)
  defp parse_quoted(<<"\\\"", rest::binary>>, acc, current),
    do: parse_quoted(rest, acc, current <> "\"")

  # Closing quote. The delimiter that follows is consumed here — letting
  # do_parse/3 see it would make it terminate a second, empty field and shift
  # every later column by one. The delimiter is not always adjacent, so skip any
  # padding first: treating "not a comma" as end-of-line drops the later fields.
  defp parse_quoted(<<"\"", rest::binary>>, acc, current) do
    case after_closing_quote(rest) do
      {:delimiter, rest} -> do_parse(rest, [current | acc], "")
      :eol -> Enum.reverse([current | acc])
      {:literal, rest} -> do_parse(rest, acc, current)
    end
  end

  defp parse_quoted(<<char::utf8, rest::binary>>, acc, current),
    do: parse_quoted(rest, acc, current <> <<char::utf8>>)

  defp after_closing_quote(<<",", rest::binary>>), do: {:delimiter, rest}

  defp after_closing_quote(<<c::utf8, rest::binary>>) when c in [?\s, ?\t],
    do: after_closing_quote(rest)

  defp after_closing_quote(""), do: :eol
  defp after_closing_quote(rest), do: {:literal, rest}
end
