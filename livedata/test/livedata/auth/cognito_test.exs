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

        # Confirm the Authorization header is present and uses the correct
        # service name "cognito-idp" (hyphen) in the credential scope.
        # ExAws.Auth.Utils.service_name/1 uses Atom.to_string only, so passing
        # :cognito_idp would produce "cognito_idp" (underscore) — the
        # service_override: :"cognito-idp" fix ensures the hyphenated form.
        {_, auth_value} = List.keyfind(conn.req_headers, "authorization", 0)
        assert auth_value =~ "cognito-idp/aws4_request"
        refute auth_value =~ "cognito_idp"

        # Cognito always responds with application/x-amz-json-1.1 (not
        # application/json), so Req returns the body as a raw JSON string.
        conn
        |> Plug.Conn.put_resp_content_type("application/x-amz-json-1.1")
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
