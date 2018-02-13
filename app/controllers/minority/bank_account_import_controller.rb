require_dependency "minority/application_controller"
require 'csv'

module Minority
  class BankAccountImportController < ApplicationController
  	before_action :admin_required!

    def index
    end

    def process
    	unless params[:input][:file].empty? or params[:input][:email].empty?
            if params[:input][:file].content_type == "text/csv"
                input_csv_file = params[:input][:file]
                email = params[:input][:email]
            else
                render json: {error: "The file is not CSV"}.to_json, status: :bad_request
            end       
        else
            render json: {error: "No file or no email given"}.to_json, status: :bad_request
        end
        
        helpers.upload_to_aws(input_csv_file)

        password = SecureRandom.hex(16)
        BankPaymentImportWorker.perform_async(aws_upload_key, password, email)

        msg = "W przeciągu kilku minut dostaniesz emaila z wynikiem na podany adres. Hasło do otwarcia pliku to: #{password}"
        render json: {message: msg}.to_json, status: :ok
    end

    def generate_template
    	csv = CSV.generate do |csv|
            csv << ["email", "bank_acct_no", "name", "address", "date", "amount", "transaction_id", "topic"]
            csv << ["foo@bar.baz", "1337", "MIŚ DUSZATEK", "UL. SMOGOWA 13/37 41-999 KRAKÓW", "2017-09-25", "0.05", "A1234567", "statutowe"]
        end

        send_data csv, type: 'text/csv; charset=utf-8; header=present', disposition: "attachment; filename=bank_imports_template.csv"
    end
  end
end
