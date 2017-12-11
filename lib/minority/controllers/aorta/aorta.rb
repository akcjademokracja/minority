require 'resolv-replace'

Tempora38::App.controllers :'aorta' do

    before do
        admin_required!
    end

    get '/manual_proc' do
        template = open(File.expand_path("../../../views/aorta/manual_proc.erb", __FILE__))
        view = ERB.new(template.read())
        view.result()
    end

    post '/manual_proc' do 
        tickets = params[:ticket_list].split(",")
        halt 400 if tickets.empty?

        tickets.each do |t|
            puts "Ticket: #{t.to_i}"
            AortaCheckTicketWorker.perform_async(t.to_i)
        end

        status 200
        {status: "accepted", tickets: tickets}.to_json
    end


end