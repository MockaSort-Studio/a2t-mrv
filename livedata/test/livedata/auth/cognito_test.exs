defmodule Livedata.Auth.CognitoTest do
  use ExUnit.Case, async: false

  alias Livedata.Auth.Cognito

  describe "authenticate/2" do
    test "maps Cognito error response to tagged error tuple" do
      Req.Test.stub(Livedata.Auth.Cognito, fn conn ->
        assert List.keyfind(conn.req_headers, "content-type", 0) ==
                 {"content-type", "application/x-amz-json-1.1"}

        assert List.keyfind(conn.req_headers, "x-amz-target", 0) ==
                 {"x-amz-target", "AmazonCognitoIdentityProvider.InitiateAuth"}

        # Confirms ExAws.Auth signed the request (Config.new resolved credentials).
        # If signing failed, the stub would never be called and the test would
        # report a stub/stub-count error rather than the real cause.
        assert List.keyfind(conn.req_headers, "authorization", 0) != nil

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          400,
          Jason.encode!(%{
            "__type" => "NotAuthorizedException",
            "message" => "Incorrect username or password."
          })
        )
      end)

      assert {:error, {"NotAuthorizedException", "Incorrect username or password."}} =
               Cognito.authenticate("user@example.com", "any-password")
    end
  end
end
