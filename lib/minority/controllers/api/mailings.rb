Tempora38::App.controllers :'api/mailings' do

  before do
    content_type :json
    get_request_payload! if request.post?
    api_authentication_required!
  end

  get '/by_test_case' do
    halt 400 unless template = params[:template]
    mailings_ids = Mailing.joins(:test_cases).
                                   where("mailing_test_cases.template LIKE ?", "%#{template}%").
                                   select('DISTINCT mailings.id').pluck(:id)

    status 200
    Mailing.where(id: mailings_ids).to_json
  end

  get '/by_subject' do
    halt 400 unless subject = params[:subject]
    mailings = Mailing.find_by(subject: subject)

    status 200
    mailings.to_json
  end

  get '/by_name' do
    halt 400 unless mailing_name = params[:name]
    mailings = Mailing.where(name: mailing_name)

    status 200
    mailings.to_json
  end

end
