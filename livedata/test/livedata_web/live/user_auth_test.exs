defmodule LivedataWeb.UserAuthTest do
  use LivedataWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  @user %{
    "sub" => "abc",
    "email" => "user@example.com",
    "name" => "Test User",
    "exp" => DateTime.utc_now() |> DateTime.add(3600) |> DateTime.to_unix()
  }

  @expired_user %{
    "sub" => "abc",
    "email" => "user@example.com",
    "name" => "Test User",
    "exp" => DateTime.utc_now() |> DateTime.add(-10) |> DateTime.to_unix()
  }

  describe "live routes behind :authenticated session" do
    test "authenticated user reaches the dashboard", %{conn: conn} do
      conn =
        conn
        |> Livedata.Auth.put_session_user(@user)
        |> Phoenix.ConnTest.init_test_session(%{})

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Your portfolio"
    end

    test "unauthenticated request is redirected to login", %{conn: conn} do
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/")
      assert path == "/auth/cognito"
    end

    test "expired token redirects to login", %{conn: conn} do
      conn =
        conn
        |> Livedata.Auth.put_session_user(@expired_user)
        |> Phoenix.ConnTest.init_test_session(%{})

      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/")
      assert path == "/auth/cognito"
    end
  end
end
