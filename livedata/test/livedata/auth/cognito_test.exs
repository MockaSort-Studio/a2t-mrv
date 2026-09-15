defmodule Livedata.Auth.CognitoTest do
  use ExUnit.Case, async: false

  alias Livedata.Auth.Cognito

  setup do
    Application.put_env(:livedata, :cognito_req_opts, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.delete_env(:livedata, :cognito_req_opts)
    end)

    :ok
  end

  describe "authenticate/2 Content-Type header" do
    test "sends application/x-amz-json-1.1 and x-amz-target on every Cognito call" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/x-amz-json-1.1"]
        assert [target] = Plug.Conn.get_req_header(conn, "x-amz-target")
        assert target == "AmazonCognitoIdentityProvider.InitiateAuth"

        conn
        |> Plug.Conn.put_resp_header("content-type", "application/json")
        |> Plug.Conn.send_resp(
          400,
          Jason.encode!(%{
            "__type" => "NotAuthorizedException",
            "message" => "Incorrect username or password."
          })
        )
      end)

      result = Cognito.authenticate("user@example.com", "any-password")

      assert {:error, {"NotAuthorizedException", "Incorrect username or password."}} = result
    end
  end
end
