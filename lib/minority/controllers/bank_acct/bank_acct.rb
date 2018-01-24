require 'unicode'

Tempora38::App.controllers :'bank_acct' do

    before do
        admin_required!
    end

    get '/import' do
      template = open(File.expand_path("../../../views/bank_acct/import.erb", __FILE__))
      view = ERB.new(template.read())
      view.result()
    end

    post '/import' do

        # {message: "Not authorized."} unless params[:email].match(/(.+)@akcjademokracja.pl/)

        if params[:file] && params[:file][:type] == "text/csv" && params[:email]
            input_csv_file = params[:file][:tempfile]
            email = params[:email]
        else
            {error: "No file/file is not CSV or no email given"}.to_json
        end

        # S3_BUCKET = Aws::S3::Resource.new.bucket(Settings.aws.s3_bucket_name)
        # def generate_s3_token
            # @s3_direct_post = S3_BUCKET.presigned_post(
            # key: "uploads/#{SecureRandom.uuid}/${filename}",
            # success_action_status: '201',
            # acl: 'public-read'
            # )
        # end

        # send the input file to AWS
        upload_key = "uploads/#{SecureRandom.uuid}/#{Time.now.strftime("%Y%m%d_%H%M%S_bank")}.csv"
        aws_obj = S3_BUCKET.put_object(
                key: upload_key,
                body: input_csv_file.path, 
                acl: 'public-read', 
                expires: Time.now + 10 * 60
        )

        password = SecureRandom.hex(16)

        BankPaymentImportWorker.perform_async(aws_obj, password, email)

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