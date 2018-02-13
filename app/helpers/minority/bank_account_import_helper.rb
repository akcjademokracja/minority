module Minority
  module BankAccountImportHelper
  	def upload_to_aws(input_csv_file)
        aws_upload_key = "uploads/#{SecureRandom.uuid}/#{Time.now.strftime("%Y%m%d_%H%M%S_bank")}.csv"
        aws_obj = S3_BUCKET.put_object(
                key: aws_upload_key,
                body: input_csv_file.read, 
                acl: 'public-read', 
                expires: Time.now + 10 * 60
        )
  	end
  end
end
