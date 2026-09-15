defmodule Livedata.Auth.ExAwsClient do
  @moduledoc false

  @callback request(struct()) :: {:ok, map()} | {:error, term()}
end
