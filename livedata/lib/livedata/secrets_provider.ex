defmodule Livedata.SecretsProvider do
  @moduledoc """
  Config.Provider that centralises all DB credentials and secret_key_base resolution.

  Three paths, resolved in order:

    1. EC2 deployment (DB_SECRET_ARN set) — credentials and secret_key_base fetched
       from AWS Secrets Manager using the instance profile. ExAws is started as a
       Config.Provider dependency before any application in the release boots.

    2. Neon / Docker (DATABASE_URL_* or DATABASE_URL set) — connection strings read
       from environment variables as-is.

    3. Local dev (mix run) — this provider never executes; Config.Provider runs only
       in releases. dev.exs and env vars handle everything.

  runtime.exs owns the non-secret prod config (endpoint URL, Cognito params, etc.)
  and is kept free of any credential fetching or external calls.

  ## Testability

  Pass `secrets_manager: ModuleName` in opts to substitute the SecretsManager
  implementation. The default is `Livedata.SecretsManager`; a test double skips
  the `Application.ensure_all_started(:ex_aws)` call automatically.
  """

  @behaviour Config.Provider

  @impl Config.Provider
  def init(opts), do: opts

  @impl Config.Provider
  def load(config, opts) do
    manager = Keyword.get(opts, :secrets_manager, Livedata.SecretsManager)

    repo_opts = resolve_db(manager)
    secret_key_base = resolve_secret_key_base(manager)

    patches =
      if(repo_opts, do: [{Livedata.Repo, repo_opts}], else: []) ++
        if secret_key_base,
          do: [{LivedataWeb.Endpoint, [secret_key_base: secret_key_base]}],
          else: []

    if patches == [] do
      config
    else
      Config.Reader.merge(config, livedata: patches)
    end
  end

  defp resolve_db(manager) do
    case System.get_env("DB_SECRET_ARN") do
      arn when is_binary(arn) and arn != "" ->
        maybe_start_ex_aws(manager)

        manager.fetch_db_config!(arn) ++
          [ssl: rds_ssl(), pool_size: pool_size(), socket_options: ipv6_opts()]

      _ ->
        case database_url() do
          nil ->
            nil

          url ->
            ssl = System.get_env("DATABASE_SSL", "true") != "false"
            [url: url, ssl: ssl, pool_size: pool_size(), socket_options: ipv6_opts()]
        end
    end
  end

  defp resolve_secret_key_base(manager) do
    case System.get_env("SECRET_KEY_BASE_SECRET_ARN") do
      arn when is_binary(arn) and arn != "" ->
        maybe_start_ex_aws(manager)
        manager.fetch_string!(arn)

      _ ->
        System.get_env("SECRET_KEY_BASE")
    end
  end

  defp maybe_start_ex_aws(Livedata.SecretsManager) do
    {:ok, _} = Application.ensure_all_started(:ex_aws)
  end

  defp maybe_start_ex_aws(_stub), do: :ok

  defp database_url do
    Enum.find_value(~w(DATABASE_URL_PR DATABASE_URL_MAIN DATABASE_URL), fn var ->
      case System.get_env(var) do
        nil -> nil
        "" -> nil
        v -> v
      end
    end)
  end

  defp rds_ssl do
    case System.get_env("DATABASE_SSL_CACERTFILE") do
      nil -> [verify: :verify_peer]
      ca_file -> [verify: :verify_peer, cacertfile: ca_file]
    end
  end

  defp pool_size, do: String.to_integer(System.get_env("POOL_SIZE", "10"))

  defp ipv6_opts, do: if(System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: [])
end
