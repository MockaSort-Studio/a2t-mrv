defmodule LivedataWeb.AuthControllerTest do
  use LivedataWeb.ConnCase, async: true

  import Mox

  alias Livedata.Auth
  alias Livedata.Auth.CognitoMock

  setup :verify_on_exit!

  @user %{
    "sub" => "user-123",
    "email" => "user@example.com",
    "name" => "Test User",
    "exp" => DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_unix()
  }

  describe "GET /auth/cognito (new/2)" do
    test "redirects to Cognito authorization URL on success", %{conn: conn} do
      expect(CognitoMock, :authorize_url, fn ->
        {:ok, "https://cognito.example.com/oauth2/authorize?client_id=x", %{state: "s"}}
      end)

      conn = get(conn, ~p"/auth/cognito")

      assert redirected_to(conn) =~ "https://cognito.example.com"
      assert get_session(conn, "cognito_session_params") == %{state: "s"}
    end

    test "redirects home with flash error when Cognito unavailable", %{conn: conn} do
      expect(CognitoMock, :authorize_url, fn ->
        {:error, :service_unavailable}
      end)

      conn = get(conn, ~p"/auth/cognito")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Authentication service"
    end
  end

  describe "GET /auth/cognito/callback (callback/2)" do
    test "stores user in session and redirects on success", %{conn: conn} do
      session_params = %{state: "abc", nonce: "xyz"}

      expect(CognitoMock, :exchange_code, fn params, ^session_params ->
        assert params["code"] == "auth_code_123"
        {:ok, @user, %{"access_token" => "tok"}}
      end)

      conn =
        conn
        |> put_session("cognito_session_params", session_params)
        |> get(~p"/auth/cognito/callback", %{code: "auth_code_123", state: "abc"})

      assert redirected_to(conn) == ~p"/"
      assert Auth.get_session_user(conn)["sub"] == "user-123"
    end

    test "honours stored redirect path after login", %{conn: conn} do
      session_params = %{state: "s"}

      expect(CognitoMock, :exchange_code, fn _params, _session ->
        {:ok, @user, %{}}
      end)

      conn =
        conn
        |> put_session("cognito_session_params", session_params)
        |> put_session("auth_return_to", "/projects/new")
        |> get(~p"/auth/cognito/callback", %{code: "code", state: "s"})

      assert redirected_to(conn) == "/projects/new"
    end

    test "redirects to login with flash on exchange failure", %{conn: conn} do
      expect(CognitoMock, :exchange_code, fn _params, _session ->
        {:error, :invalid_grant}
      end)

      conn =
        conn
        |> put_session("cognito_session_params", %{state: "s"})
        |> get(~p"/auth/cognito/callback", %{code: "bad", state: "s"})

      assert redirected_to(conn) == ~p"/auth/cognito"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Authentication failed"
    end
  end

  describe "DELETE /auth/cognito (delete/2)" do
    test "clears session and redirects home", %{conn: conn} do
      conn =
        conn
        |> Auth.put_session_user(@user)
        |> delete(~p"/auth/cognito")

      assert redirected_to(conn) == ~p"/"
      assert Auth.get_session_user(conn) == nil
    end
  end
end
