class MemberActionData < ActiveRecord::Base
  scope :by_key, lambda { |key|
    joins(:action_key).
      where(action_keys: {key: key.to_s})
  }

  def to_i
    value.to_i
  end

  def to_s
    value.to_s
  end

  def to_sym
    value.to_sym
  end

  def to_f
    value.to_f
  end
end
