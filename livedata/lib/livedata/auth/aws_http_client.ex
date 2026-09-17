defmodule Livedata.Auth.AwsHttpClient do
  @moduledoc false
  @behaviour AWS.HTTPClient

  @impl true
  def request(method, url, body, headers, _options) do
    case Req.request(
           method: method,
           url: url,
           body: IO.iodata_to_binary(body),
           headers: headers,
           decode_body: false
         ) do
      {:ok, resp} ->
        {:ok, %{status_code: resp.status, headers: resp.headers, body: resp.body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
