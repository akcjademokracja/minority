
Tempora38::App.controllers :'api/gdpr' do

  before do
    get_request_payload!
    cross_origin
    api_authentication_required!
  end

  post '/forget' do
    if @request_payload.has_key?(:email)
      member = Member.find_by email: @request_payload[:email]
      if member.nil?
        halt 404
      end

      success = Member::GDPR.optout(member, @request_payload[:reason] || "GDPR forget request")
      halt 400 unless success

      {}.to_json
    else
      halt 400
    end
  end

  post '/optout' do

    if @request_payload.has_key?(:email)
      member = Member.find_by email: @request_payload[:email]
      if member.nil?
        halt 404
      end
    end

    success = Member::GDPR.optout(member, @request_payload[:reason] || "GDPR optout request")
    halt 400 unless success

    {}.to_json
  end

end
