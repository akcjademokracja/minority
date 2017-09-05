class DonationFromActionWorker
  include Sidekiq::Worker

  def perform(member_action_id)
    member_action = MemberAction.
                    joins(:action).
                    includes(:member_action_datas).
                    where({
                            id: member_action_id,
                            actions: {
                              action_type: 'donate'
                            }
                          }).first
    return if member_action.nil?

    donation = self.make_donation member_action

    donation = self.save_donation donation

    regular_donation = update_regular_donation(donation, member_action)

    member_action.member.recalculate_donation_statistics

    [donation, regular_donation]
    # member_action.by_key(:)
    # amount -> amount
    # payment_processor -> external_source
    # transaction_id -> external_id 
    # payment_processor -> medium ?

    # regular--
    # started_at
    # ended_at
    # frequency: monthly
    # smartdebit_reference could be 
  end

  def make_donation(ma)
    data = ma.member_action_datas
    donation = Donation.new(
      {
        amount: data.by_key(:amount).first.to_i,
        external_source: data.by_key(:payment_processor).first.to_s, # order id of rdonate?
        external_id: data.by_key(:transaction_id).first.to_s,
        medium: data.by_key(:card_type).first.to_s,
        member_action: ma,
        member: ma.member,
        created_at: ma.created_at,
        updated_at: ma.updated_at
      })

    # we can use tx id as nonce as we already know tx happened
    donation.nonce = donation.external_id
    donation
  end

  def save_donation(donation)
    Donation.transaction do
      d = Donation.find_by external_id: donation.external_id
      unless d.nil?
        Padrino.logger.info "Not saving a duplicate donation #{donation.external_id}"
        return d
      end

      donation.save!
      donation
    end
  end

  def set_from_initial_donation(rd, donation)
    rd.created_at = donation.created_at
    rd.updated_at = donation.updated_at
    rd.started_at = donation.created_at

    rd.initial_amount = donation.amount
    rd.medium = donation.member_action.source.try(:medium)
    rd.source = donation.member_action.source.try(:source)
  end

  def update_regular_donation(donation, member_action)
    recurring_id = member_action.member_action_datas.by_key(:recurring_id).first.to_s
    unless recurring_id.blank?
      rd = RegularDonation.
           find_or_initialize_by({
                               member: member_action.member,
                               external_id: recurring_id,
                             })
      if rd.new_record?
        set_from_initial_donation(rd, donation)
        rd.frequency = 'monthly'
        rd.current_amount = donation.amount
        rd.amount_last_changed_at = donation.created_at
        rd.ended = false
      else
        # the recurring donation was in reality started earlier
        if donation.created_at < rd.created_at
          set_from_initial_donation(rd, donation)
        end

        # modify current amount
        if donation.created_at > rd.amount_last_changed_at and
          donation.amount != rd.current_amount
          rd.current_amount = donation.amount
          rd.amount_last_changed_at = rd.created_at
        end

        # re-open the recurring donation
        if rd.ended and rd.ended_at < donation.created_at
          rd.ended = false
          rd.ended_at = donation.created_at
        end
      end

      rd.save!
      rd
    end
  end
end
