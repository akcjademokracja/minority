# coding: utf-8
require_relative './identity_lookup.rb'

class BankPaymentImportWorker
  include Sidekiq::Worker

  def perform(aws_upload_key, password, email)
    identity = IdentityLookup.new
    csv = Aws::S3::Client.new.get_object(key: aws_upload_key, bucket: S3_BUCKET.name).body.read

    CSV.parse(csv, headers: true, col_sep: ";").each do |donation|
      donator = identity.locate(donation)

      is_regular_donation = heuristics(donation["payment_title"])

      if donator
        # create Donation

        begin
          dt = DateTime.parse(donation["date"])
        rescue StandardError => e
          Rails.logger.error("Bad date format #{donation['date']}: #{e.message}")
          next
        end
        new_donation = Donation.new({
                                      amount: donation["amount"].to_f,
                                      member: donator, 
                                      external_id: donation["transaction_id"].to_s,
                                      medium: "konto",
                                      created_at: dt
                                    })

        if Donation.find_by(external_id: new_donation.external_id) or Donation.find_by(amount: donation["amount"].to_f, member: donator, created_at: DateTime.parse(donation["date"]))
          Rails.logger.info("Ignoring duplicate donation #{new_donation.external_id}")
          identity.csv_result << Array.new(donation.to_h.values.count + 1) + ["ignoring duplicate donation #{new_donation.external_id}"]
        else
          identity.csv_result << Array.new(donation.to_h.values.count + 1) + ["creating new donation #{new_donation.external_id}"]
          new_donation.save!
        end

        # XXX create regular donations
        new_rdonation = RegularDonation.find_or_create_by!(
          member: donator,
          source: "konto",
        ) if is_regular_donation
      else
        Rails.logger.info("Donator not found.")
        identity.csv_result << donation.to_h.values + ["the donator hasn't been found!"]
      end
    end

    # preparing data for export
    data = CSV.generate do |csv|
      csv << ["email", "bank_acct_no", "name", "address", "date", "amount", "transaction_id", "payment_title", "topic", "status"]
      identity.csv_result.each do |ary|
        csv << ary
      end
    end

    pack_and_send_by_email(email, password, data)
  end

  private

  def heuristics(title_line)
    # based on title line

    return false unless title_line

    # TODO just strip the Polish symbols instead of defining them
    regular_payment_kw = %w[
      regularna regularne regularny
      cykliczna cykliczny 
      comiesięczne comiesięczna
      comiesieczne comiesieczna 
      miesięczne miesięczna
      miesieczne miesieczna
      stałe stała
      stale stala
      styczeń styczen
      luty
      marzec
      kwiecień kwiecien
      maj
      czerwiec
      lipiec
      sierpień sierpien
      wrzesień wrzesien
      październik pazdziernik
      listopad
      grudzień grudzien
      I II III IV V VI VII VIII IX X XI XII
      01 02 03 04 05 06 07 08 09 10 11 12
    ]

    regular_payment_kw.find { |kw| /#{kw}/ =~ title_line } ? true : false
  end

  def pack_and_send_by_email(email, password, data)
    timestamp = Time.now.iso8601.to_s.gsub(':', '')
    zip_filename = "bank_acct-#{timestamp}.zip"

    zip_file = Zip::OutputStream.write_buffer(::StringIO.new(''), Zip::TraditionalEncrypter.new(password)) do |zip|
      zip.put_next_entry("donations_output.csv")
      zip.write(data)
    end
    zip_file.rewind
    File.new(zip_filename, "wb").write(zip_file.sysread)

    TransactionalMail.send_email(
      to: [email],
      subject: "Wynik importu wplat recznych z #{timestamp}",
      body: 'Hej,',
      from: "#{Settings.app.org_title} <#{Settings.options.default_mailing_from_email}>",
      source: 'identity:email-csv',
      files: [
                {
                  path: zip_filename,
                  filename: zip_filename
                }
             ]
    )
  end
end
