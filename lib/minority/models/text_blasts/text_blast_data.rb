class TextBlastData < Mustache
  def vocative
    FirstName.where("first_name ILIKE ?", @member.first_name).first.try(:vocative) || @member.first_name
  end
end
