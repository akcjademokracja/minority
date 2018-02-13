require_dependency "minority/application_controller"

module Minority
  class AortaManualProcController < ApplicationController
  	before_action :admin_required!
  	
    def index
    end

    def process
    	tickets = params[:ticket_list].split(",")
    	render status: :bad_request if tickets.empty?

    	tickets.each do |t|
    		puts "Ticket: #{t.to_i}"
            AortaCheckTicketWorker.perform_async(t.to_i)
    	end

    	render json: {status: "accepted", tickets: tickets}.to_json, status: :ok
    end
  end
end
