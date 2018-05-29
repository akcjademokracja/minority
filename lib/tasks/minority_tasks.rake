# coding: utf-8
# desc "Explaining what the task does"
# task :minority do
#   # Task goes here
# end

require 'csv'

namespace :action_data do
  desc "Import fixed CSV data"
  task import: :environment do
    unless ENV["fpath"]
        puts "No file given. Specify the file path with `fpath=*.csv`"
        exit
    end

    CSV.foreach(ENV["fpath"], headers: true) do |imported_action|
      a = Action.find(imported_action["id"].to_i)
      orig_name = a.name

      ["name", "action_type", "description", "external_id"].each do |field|
        field_from_db = a.send(field)
        field_from_csv = imported_action[field]

        unless field_from_db.eql? field_from_csv
          a.update(field.to_sym => field_from_csv)
        end
      end

      if imported_action["campaign"]
        unless a.campaign.name.eql? imported_action["campaign"]
          new_c_id = Campaign.find_by(name: imported_action["campaign"]).id
          a.update(campaign_id: new_c_id)
        end
      end

      if imported_action["issue"]
        if a.campaign.issue.nil? or a.campaign.issue.name != imported_action["issue"]
          fixed_issue = Issue.find_by(name: imported_action["issue"])
          a.campaign.update(issue_id: fixed_issue.id) unless fixed_issue.nil?
        end
      end

      puts "#{orig_name} updated."

    end

    puts "Operation finished."
  end

  desc "Export the action data to CSV"
  task export: :environment do
    action_data = [].append(["created_at", "id", "name", "action_type", "campaign", "issue", "description", "external_id"])
    Action.all.each do |a|
      action_data << [a.created_at, a.id, a.name, 
                      a.action_type, a.campaign.try(:name) || "", 
                      a.try(:campaign).try(:issue).try(:name) || "", 
                      a.description, a.external_id]
    end

    IO.write("action_data.csv", action_data.map(&:to_csv).join)
    puts "#{action_data.count - 1} actions exported."
  end

end


namespace :consents do 
  desc "Create Akcja consents"
  task create: :environment do
    ct = ConsentText.create!({
                               public_id: 'gdpr_campaign_1.0',
                               consent_short_text: 'Zgadzam się na przetwarzanie moich danych w celu przeprowadzenia tylko tej kampanii.',
                               full_legal_text_link: 'https://akcjademokracja.pl/rodo/kampanie'
                             })

    ct = ConsentText.create!({
                               public_id: 'gdpr_all_1.0',
                               consent_short_text: 'Zgadzam się na przetwarzanie moich danych w celu informowaniu mnie o  kampaniach oraz w celu przeprowadzenia tych kampanii, w których zechcę wziąć udział, poprzez e-mail, telefon, SMS oraz inne kanały komunikacji elektronicznej.',
                               full_legal_text_link: 'https://akcjademokracja.pl/rodo/informowanie'
                             })
  end
end

namespace :csl do
  desc "Link CSL consents to ConsentTexts"
  task link_consents: :environment do
    ControlshiftConsent.all.each do |csc|
      ct = ConsentText.find_by(public_id: csc.controlshift_consent_external_id.split("-").last)

      ControlshiftConsentMapping.create!(
        consent_text: ct, 
        controlshift_consent: csc
        # XXX incomplete, consult the ControlshiftConsentMapping model
      )
    end
  end
end
