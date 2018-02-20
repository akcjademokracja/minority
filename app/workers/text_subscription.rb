# Adds sms subscription to people with no subscriptions, but phone number given.
class TextSubscription
  include Sidekiq::Worker

  def perform()
    sms = Subscription.find Subscription::SMS_SUBSCRIPTION
    m = Member.joins(:phone_numbers).
      joins(%Q{LEFT JOIN member_subscriptions
               ON member_subscriptions.member_id = members.id
               AND member_subscriptions.subscription_id = #{sms.id}}).
      where(member_subscriptions: { id: nil })
    m.each do |m|
      m.subscribe_to sms
    end
  end
end
