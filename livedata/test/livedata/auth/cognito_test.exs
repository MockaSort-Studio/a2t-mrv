defmodule Livedata.Auth.CognitoTest do
  use ExUnit.Case, async: false

  import Mox

  alias Livedata.Auth.Cognito

  setup :verify_on_exit!

  describe "authenticate/2" do
    test "sends application/x-amz-json-1.1 and x-amz-target headers via ExAws" do
      Mox.expect(Livedata.MockExAws, :request, fn op ->
        assert {"content-type", "application/x-amz-json-1.1"} in op.headers
        assert {"x-amz-target", "AmazonCognitoIdentityProvider.InitiateAuth"} in op.headers

        {:error,
         {:http_error, 400,
          %{"__type" => "NotAuthorizedException", "message" => "Incorrect username or password."}}}
      end)

      assert {:error, {"NotAuthorizedException", "Incorrect username or password."}} =
               Cognito.authenticate("user@example.com", "any-password")
    end
  end
end
