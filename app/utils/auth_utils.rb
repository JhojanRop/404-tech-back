module AuthUtils
  def decode_token(header, secret_key)
    return nil unless header.present? && header.start_with?('Bearer ')
    token = header.split(' ').last
    begin
      decoded = JWT.decode(token, secret_key)[0]
      decoded
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end
  end

  def current_user(header, secret_key)
    decoded = decode_token(header, secret_key)
    return nil unless decoded && decoded['user_id']
    user_doc = USERS_COLLECTION.doc(decoded['user_id']).get
    user_doc.exists? ? user_doc : nil
  end

  def user_role(user_doc)
    user_doc.data['role'] || user_doc.data[:role]
  end

  def authorize_admin_or_editor!
    header = request.headers['Authorization']
    secret_key = Rails.application.credentials.secret_key_base || ENV['SECRET_KEY_BASE']
    user_doc = current_user(header, secret_key)
    unless user_doc && ['admin', 'editor'].include?(user_role(user_doc))
      render json: { error: 'Admin or editor privileges required' }, status: :forbidden and return
    end
  end
end