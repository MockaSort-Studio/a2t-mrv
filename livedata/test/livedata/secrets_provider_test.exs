defmodule Livedata.SecretsProviderTest do
  use ExUnit.Case, async: false

  alias Livedata.SecretsProvider

  # Inline stub — avoids starting ExAws in tests.
  defmodule StubSecretsManager do
    def fetch_db_config!("arn:aws:secretsmanager:eu-north-1:123:secret:db") do
      [
        hostname: "rds.example.com",
        port: 5432,
        username: "dbuser",
        password: "s3cr3t",
        database: "app_prod"
      ]
    end

    def fetch_string!("arn:aws:secretsmanager:eu-north-1:123:secret:skb") do
      "a_very_long_secret_key_base_value_for_testing_purposes"
    end
  end

  @base_config [livedata: [{Livedata.Repo, [types: Livedata.PostgrexTypes]}]]
  @opts [secrets_manager: StubSecretsManager]

  setup do
    # Snapshot all env vars touched by the provider and restore them after each test.
    vars =
      ~w(DB_SECRET_ARN SECRET_KEY_BASE_SECRET_ARN DATABASE_URL_PR DATABASE_URL_MAIN DATABASE_URL SECRET_KEY_BASE DATABASE_SSL DATABASE_SSL_CACERTFILE POOL_SIZE ECTO_IPV6)

    saved = Enum.map(vars, &{&1, System.get_env(&1)})

    on_exit(fn ->
      Enum.each(saved, fn
        {k, nil} -> System.delete_env(k)
        {k, v} -> System.put_env(k, v)
      end)
    end)

    Enum.each(vars, &System.delete_env/1)
    :ok
  end

  describe "load/2 — no credentials configured" do
    test "returns config unchanged when no env vars are set" do
      result = SecretsProvider.load(@base_config, @opts)
      assert result == @base_config
    end

    test "returns config unchanged when DATABASE_URL vars are all blank strings" do
      System.put_env("DATABASE_URL_PR", "")
      System.put_env("DATABASE_URL_MAIN", "")
      System.put_env("DATABASE_URL", "")
      result = SecretsProvider.load(@base_config, @opts)
      assert result == @base_config
    end
  end

  describe "load/2 — DATABASE_URL path" do
    test "merges Repo config from DATABASE_URL_MAIN" do
      System.put_env("DATABASE_URL_MAIN", "ecto://user:pass@host/mydb")
      result = SecretsProvider.load(@base_config, @opts)
      repo = get_repo_config(result)
      assert repo[:url] == "ecto://user:pass@host/mydb"
      assert repo[:ssl] == true
    end

    test "DATABASE_URL_PR takes precedence over DATABASE_URL_MAIN" do
      System.put_env("DATABASE_URL_PR", "ecto://pr/prdb")
      System.put_env("DATABASE_URL_MAIN", "ecto://main/maindb")
      result = SecretsProvider.load(@base_config, @opts)
      assert get_repo_config(result)[:url] == "ecto://pr/prdb"
    end

    test "DATABASE_URL_MAIN takes precedence over DATABASE_URL" do
      System.put_env("DATABASE_URL_MAIN", "ecto://main/maindb")
      System.put_env("DATABASE_URL", "ecto://legacy/legacydb")
      result = SecretsProvider.load(@base_config, @opts)
      assert get_repo_config(result)[:url] == "ecto://main/maindb"
    end

    test "falls through to DATABASE_URL when PR and MAIN are blank" do
      System.put_env("DATABASE_URL_PR", "")
      System.put_env("DATABASE_URL_MAIN", "")
      System.put_env("DATABASE_URL", "ecto://legacy/legacydb")
      result = SecretsProvider.load(@base_config, @opts)
      assert get_repo_config(result)[:url] == "ecto://legacy/legacydb"
    end

    test "DATABASE_SSL=false disables TLS" do
      System.put_env("DATABASE_URL_MAIN", "ecto://user:pass@host/mydb")
      System.put_env("DATABASE_SSL", "false")
      result = SecretsProvider.load(@base_config, @opts)
      assert get_repo_config(result)[:ssl] == false
    end

    test "POOL_SIZE is applied" do
      System.put_env("DATABASE_URL_MAIN", "ecto://user:pass@host/mydb")
      System.put_env("POOL_SIZE", "3")
      result = SecretsProvider.load(@base_config, @opts)
      assert get_repo_config(result)[:pool_size] == 3
    end

    test "does not patch Endpoint when SECRET_KEY_BASE is unset" do
      System.put_env("DATABASE_URL_MAIN", "ecto://user:pass@host/mydb")
      result = SecretsProvider.load(@base_config, @opts)
      refute get_endpoint_config(result)[:secret_key_base]
    end
  end

  describe "load/2 — Secrets Manager path (via stub)" do
    @db_arn "arn:aws:secretsmanager:eu-north-1:123:secret:db"
    @skb_arn "arn:aws:secretsmanager:eu-north-1:123:secret:skb"

    test "fetches DB config from stub and merges Repo opts" do
      System.put_env("DB_SECRET_ARN", @db_arn)
      result = SecretsProvider.load(@base_config, @opts)
      repo = get_repo_config(result)
      assert repo[:hostname] == "rds.example.com"
      assert repo[:port] == 5432
      assert repo[:username] == "dbuser"
      assert repo[:password] == "s3cr3t"
      assert repo[:database] == "app_prod"
    end

    test "applies verify_peer SSL when no cacertfile" do
      System.put_env("DB_SECRET_ARN", @db_arn)
      result = SecretsProvider.load(@base_config, @opts)
      assert get_repo_config(result)[:ssl] == [verify: :verify_peer]
    end

    test "applies cacertfile when DATABASE_SSL_CACERTFILE is set" do
      System.put_env("DB_SECRET_ARN", @db_arn)
      System.put_env("DATABASE_SSL_CACERTFILE", "/etc/livedata/rds-ca-bundle.pem")
      result = SecretsProvider.load(@base_config, @opts)

      assert get_repo_config(result)[:ssl] == [
               verify: :verify_peer,
               cacertfile: "/etc/livedata/rds-ca-bundle.pem"
             ]
    end

    test "fetches secret_key_base from stub and patches Endpoint" do
      System.put_env("SECRET_KEY_BASE_SECRET_ARN", @skb_arn)
      result = SecretsProvider.load(@base_config, @opts)

      assert get_endpoint_config(result)[:secret_key_base] ==
               "a_very_long_secret_key_base_value_for_testing_purposes"
    end

    test "uses SECRET_KEY_BASE env var when ARN not set" do
      System.put_env("SECRET_KEY_BASE", "my_env_secret_key_base")
      result = SecretsProvider.load(@base_config, @opts)
      assert get_endpoint_config(result)[:secret_key_base] == "my_env_secret_key_base"
    end

    test "DB and secret_key_base are both merged in one pass" do
      System.put_env("DB_SECRET_ARN", @db_arn)
      System.put_env("SECRET_KEY_BASE_SECRET_ARN", @skb_arn)
      result = SecretsProvider.load(@base_config, @opts)
      assert get_repo_config(result)[:hostname] == "rds.example.com"

      assert get_endpoint_config(result)[:secret_key_base] ==
               "a_very_long_secret_key_base_value_for_testing_purposes"
    end
  end

  defp get_repo_config(config) do
    config
    |> Keyword.get(:livedata, [])
    |> Keyword.get(Livedata.Repo, [])
  end

  defp get_endpoint_config(config) do
    config
    |> Keyword.get(:livedata, [])
    |> Keyword.get(LivedataWeb.Endpoint, [])
  end
end
