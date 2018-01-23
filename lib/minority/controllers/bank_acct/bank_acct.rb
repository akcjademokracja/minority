require 'unicode'

Tempora38::App.controllers :'bank_acct' do

    before do
        admin_required!
    end

    get '/import' do
        generate_s3_token
        b = binding 
        b.local_variable_set(:s3_direct_post, @s3_direct_post)
        template = open(File.expand_path("../../../views/bank_acct/import.erb", __FILE__))
        view = ERB.new(template.read())
        view.result(b)
    end

    post '/import' do
        url = params['file_url']
        email = params["email"]
        if params[:file] && params[:file][:type] == "text/csv" && params[:email]
            email = params[:email]
        else
            {error: "No file/file is not CSV or no email given"}.to_json
        end
        password = SecureRandom.hex(16)
        BankPaymentImportWorker.perform_async(url, password, email)
        {message: "W przeciągu kilku minut dostaniesz emaila z wynikiem na podany adres. Hasło do otwarcia pliku to: #{password}"}.to_json
    end

    get 'generate_template' do 
        content_type 'application/csv'
        attachment 'donations_template.csv'

        CSV.generate do |csv|
            csv << ["email", "bank_acct_no", "name", "address", "date", "amount", "transaction_id", "topic"]
            csv << ["foo@bar.baz", "1337", "MIŚ DUSZATEK", "UL. SMOGOWA 13/37 41-999 KRAKÓW", "2017-09-25", "0.05", "A1234567", "statutowe"]
        end
    end
end