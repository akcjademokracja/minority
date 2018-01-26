class TextBlastData < Mustache
  def vocative
    FirstName.find_by(first_name: @member.first_name).try(:vocative) || @member.first_name
  end
end
