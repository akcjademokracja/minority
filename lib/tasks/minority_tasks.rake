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
      a.update(
                name: imported_action["name"], 
                action_type: imported_action["action_type"], 
                description: imported_action["description"]
              )
      a.update(campaign_id: Campaign.find_by(name: imported_action["campaign"]).id) unless imported_action["campaign"].empty?
      a.issue.update(id: Issue.find_by(name: imported_action["issue"]).id) unless imported_action["issue"].empty?
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
