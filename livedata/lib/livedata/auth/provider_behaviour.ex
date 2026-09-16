defmodule Livedata.Auth.ProviderBehaviour do
  @moduledoc """
  Behaviour contract for authentication backends.

  Backends implement this and are registered under the `:auth_provider`
  application config key. Callers use `Livedata.Auth.Provider` and never
  reference a specific backend module.
  """

  @type user_identity :: %{String.t() => String.t() | integer() | nil}
  @type challenge_data :: map()

  @callback authenticate(username :: String.t(), password :: String.t()) ::
              {:ok, user_identity()}
              | {:challenge, :new_password_required, challenge_data()}
              | {:error, term()}

  @callback respond_new_password(
              username :: String.t(),
              new_password :: String.t(),
              challenge_data :: challenge_data()
            ) ::
              {:ok, user_identity()} | {:error, term()}

  @callback refresh_token(username :: String.t(), refresh_token :: String.t()) ::
              {:ok, user_identity()} | {:error, term()}
end
