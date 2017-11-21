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

        tickets.each do |t|
            AortaCheckTicketWorker.new.perform(t.to_i)
        end
    end


end