require 'bunny'

class AortaMainWorker
    include Sidekiq::Worker

    def perform

        # Make a connection first
        begin
            @conn = Bunny.new(ENV['AMQP_URL'])
            @conn.start
        rescue Bunny::TCPConnectionFailed => e
            puts "Connection to RabbitMQ failed!"
        end

        # Process
        begin
            ch = @conn.create_channel
            q = ch.queue(ENV['AMQP_QUEUE_NAME'], durable: true)

            q.subscribe(block: false, manual_ack: true) do |delivery_info, properties, payload|
                message_type, message_details = JSON.parse(payload)
            end

            case message_type
                when "freshdesk_check_ticket"
                    # Let's just acknowledge this message so that RabbitMQ doesn't requeue it
                    # After acknowledging, delegate the work to a specified worker

                    ch.ack(delivery_info.delivery_tag)
                    AortaCheckTicketWorker.perform_async(message_details["ticket_id"])
                else
            end
        rescue Bunny::PreconditionFailed => e
            puts "Channel-level exception! Code: #{e.channel_close.reply_code}, message: #{e.channel_close.reply_text}".squish
        ensure
            ch.close
            @conn.close
        end

    end
end