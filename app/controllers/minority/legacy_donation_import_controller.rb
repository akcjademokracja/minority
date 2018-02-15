require_dependency "minority/application_controller"
require 'csv'

module Minority
  class LegacyDonationImportController < ApplicationController
  	before_action :admin_required!
    helper LegacyDonationImportHelper

    def index
    end

    def import
    	unless params[:file].nil? or params[:email].empty?
            if params[:file].content_type == "text/csv"
                input_csv_file = params[:file]
                email = params[:email]
            else
                render json: {error: "The file is not CSV"}, status: :bad_request and return
            end       
        else
            render json: {error: "No file or no email given"}, status: :bad_request and return
        end
        
        aws_upload_key = helpers.upload_to_aws(input_csv_file)

        password = SecureRandom.hex(16)
        BankPaymentImportWorker.perform_async(aws_upload_key, password, email)

        msg = "W przeciągu kilku minut dostaniesz emaila z wynikiem na podany adres. Hasło do otwarcia pliku to: #{password}"
        render json: {message: msg}, status: :ok
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
