defmodule Livedata.Auth.CognitoBehaviour do
  @moduledoc """
  Behaviour for the Cognito auth client — enables swapping implementations
  between real Cognito (EC2), CognitoMock (dev/test/Render), and Mox in unit tests.

  @req: KR 8.3
  """

  @type user_identity :: %{
          String.t() => String.t() | integer() | nil
        }

  @callback authenticate(username :: String.t(), password :: String.t()) ::
              {:ok, user_identity()} | {:error, term()}

  @callback refresh_token(refresh_token :: String.t()) ::
              {:ok, user_identity()} | {:error, term()}
end
