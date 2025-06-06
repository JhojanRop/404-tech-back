module UserUtils
  def valid_email?(email)
    /\A[^@\s]+@[^@\s]+\z/.match?(email)
  end

  def valid_password?(password)
    password.length >= 8
  end

  def find_user_by_email(email)
    user_query = USERS_COLLECTION.where(:email, :==, email).get.to_a
    Rails.logger.info "USER FOUND: #{user_query.first&.data.inspect}"
    user_query.empty? ? nil : user_query.first
  end

  def clean_user_data(data, id = nil)
    cleaned = data.transform_keys(&:to_s)
    cleaned.delete('password_hash')
    cleaned['id'] = id if id
    cleaned
  end
end