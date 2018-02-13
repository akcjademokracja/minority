require 'test_helper'

module Minority
  class BankAccountImportControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    test "should get index" do
      get bank_account_import_index_url
      assert_response :success
    end

  end
end
