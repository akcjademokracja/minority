require 'test_helper'

module Minority
  class AortaManualProcControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    test "should get index" do
      get aorta_manual_proc_index_url
      assert_response :success
    end

  end
end
