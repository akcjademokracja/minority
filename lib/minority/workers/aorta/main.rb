require 'bunny'

class AortaMainWorker
    include Sidekiq::Worker

    def perform
      return if ENV['AMQP_URL'].blank?

        # Estabilish a connection first
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

            # Don't do anything if the queue is empty. If it wasn't for that, we'd have too much MainWorkers
            # which would then throw Timeout::Errors.
            unless q.message_count == 0
                # If it was block: false, it'd spawn the consumer in an another thread...
                # and since this worker is run every 5 minutes, you'd get another thread every 5 minutes.
                # The subscribers would basically exist and be idle somewhere, waiting for messages.
                q.subscribe(block: true, manual_ack: true) do |delivery_info, properties, payload|
                message_type, message_details = JSON.parse(payload)

                    case message_type
                    when "freshdesk_check_ticket"
                            # Let's just acknowledge this message so that RabbitMQ doesn't requeue it
                            # After acknowledging, delegate the work to a specified worker

                            ch.ack(delivery_info.delivery_tag)
                            AortaCheckTicketWorker.perform_async(message_details["ticket_id"])
                    else
                    end
                
                end
            end

        rescue Bunny::PreconditionFailed => e
            puts "Channel-level exception! Code: #{e.channel_close.reply_code}, message: #{e.channel_close.reply_text}".squish
        ensure
            ch.close
            @conn.close
        end

    end
end
