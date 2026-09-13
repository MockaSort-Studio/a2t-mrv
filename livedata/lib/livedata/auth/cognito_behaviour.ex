defmodule Livedata.Auth.CognitoBehaviour do
  @moduledoc """
  Behaviour for the Cognito OIDC client — enables Mox-based testing.

  @req: KR 8.3
  """

  @callback authorize_url() ::
              {:ok, url :: String.t(), session_params :: map()} | {:error, term()}

  @callback exchange_code(params :: map(), session_params :: map()) ::
              {:ok, user :: map(), token :: map()} | {:error, term()}
end
