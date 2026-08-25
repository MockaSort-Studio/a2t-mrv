import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/livedata start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :livedata, LivedataWeb.Endpoint, server: true
end

config :livedata, LivedataWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :prod do
  # Which database this instance talks to, in precedence order:
  #
  #   DATABASE_URL_PR   — a Neon branch, written by .github/workflows/preview.yml
  #                       while a pull request owns the shared Render service.
  #   DATABASE_URL_MAIN — production. Never written by CI; entered by hand.
  #   DATABASE_URL      — honoured last so a deployment predating the preview
  #                       workflow keeps running unchanged.
  #
  # Render has no indirection like Koyeb's `DATABASE_URL=@SECRET`, so the choice
  # has to happen here. The point is that CI only ever writes the PR variable:
  # production's connection string cannot be clobbered by a preview.
  #
  # Blank counts as unset. Deleting a Render env var removes it, but a var left
  # as "" would otherwise win here — `System.get_env/1` returns "", which is
  # truthy in Elixir — and silently point production at nothing.
  database_url =
    Enum.find_value(~w(DATABASE_URL_PR DATABASE_URL_MAIN DATABASE_URL), fn var ->
      case System.get_env(var) do
        nil -> nil
        "" -> nil
        value -> value
      end
    end) ||
      raise """
      no database connection string is set.
      Set DATABASE_URL_MAIN (or DATABASE_URL), for example:
      ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  # DATABASE_SSL controls Postgrex TLS. Default "true" (verify-peer against OS
  # trust store) is correct for Neon and other managed providers. Set to "false"
  # for a self-hosted Postgres container without TLS configured (e.g. the Docker
  # Compose deployment in deploy/compose.yml). Never set to "false" in production
  # against a remote database — see docs/contributing/deployment.md.
  # @req: REQ-87
  database_ssl = System.get_env("DATABASE_SSL", "true") != "false"

  config :livedata, Livedata.Repo,
    ssl: database_ssl,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :livedata, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :livedata, LivedataWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/bandit/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :livedata, LivedataWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :livedata, LivedataWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :livedata, Livedata.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.
end
