require 'bcrypt'
require 'jwt'

require Rails.root.join('app', 'utils', 'auth_utils.rb')
require Rails.root.join('app', 'utils', 'user_utils.rb')

class UsersController < ApplicationController
  include UserUtils
  include AuthUtils

  SECRET_KEY = Rails.application.credentials.secret_key_base || ENV['SECRET_KEY_BASE']

  before_action :authorize_request, except: [:login, :create]
  before_action :authorize_admin, except: [:login, :create, :show]

  rescue_from StandardError do |e|
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end

  # GET /users
  def index
    users = USERS_COLLECTION.get.map do |doc|
      clean_user_data(doc.data, doc.document_id)
    end
    render json: users
  end

  # POST /login
  def login
    begin
      email = params[:email]
      password = params[:password]

      if email.blank? || password.blank?
        return render json: { error: 'Email and password required' }, status: :bad_request
      end

      doc = find_user_by_email(email)
      unless doc
        return render json: { error: 'Invalid email or password' }, status: :unauthorized
      end

      user_data = doc.data

      password_hash = user_data['password_hash'] || user_data[:password_hash]
      Rails.logger.info "HASH ENCONTRADO: #{password_hash.inspect}"

      if password_hash.present? && BCrypt::Password.new(password_hash) == password
        payload = { user_id: doc.document_id, email: user_data['email'], exp: 24.hours.from_now.to_i }
        token = JWT.encode(payload, SECRET_KEY)
        user_data = user_data.dup
        user_data.delete('password_hash')
        user_data.delete(:password_hash)
        render json: { token: token, user: clean_user_data(user_data).merge(id: doc.document_id) }
      else
        render json: { error: 'Invalid email or password' }, status: :unauthorized
      end
    rescue => e
      Rails.logger.error "LOGIN ERROR: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: 'Internal server error', detail: e.message }, status: :internal_server_error
    end
  end

  # GET /users/:id
  def show
    doc = USERS_COLLECTION.doc(params[:id]).get
    if doc.exists?
      render json: clean_user_data(doc.data, doc.document_id)
    else
      render json: { error: 'User not found' }, status: :not_found
    end
  end

  # PUT /users/:id
  def update
    doc = USERS_COLLECTION.doc(params[:id])
    if doc.get.exists?
      data = user_params.to_h.symbolize_keys

      if data[:password].present?
        data[:password_hash] = BCrypt::Password.create(data.delete(:password))
      end
      data[:updatedAt] = Time.now.utc.iso8601

      begin
        doc.update(data)
        updated_user = doc.get.data.dup
        updated_user.delete('password_hash')
        updated_user.delete(:password_hash)
        render json: clean_user_data(updated_user, doc.document_id)
      rescue => e
        Rails.logger.error "UPDATE ERROR: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: 'Internal server error', detail: e.message }, status: :internal_server_error
      end
    else
      render json: { error: 'User not found' }, status: :not_found
    end
  end

  # DELETE /users/:id
  def destroy
    doc = USERS_COLLECTION.doc(params[:id])
    if doc.get.exists?
      doc.delete
      head :no_content
    else
      render json: { error: 'User not found' }, status: :not_found
    end
  end

  # POST /users
  def create
    begin
      data = user_params.to_h
      password = data.delete(:password) || data.delete('password')
      unless password.present? && valid_password?(password)
        return render json: { error: 'Password must be at least 8 characters' }, status: :unprocessable_entity
      end

      unless valid_email?(data['email'] || data[:email])
        return render json: { error: 'Invalid email format' }, status: :unprocessable_entity
      end

      if find_user_by_email(data['email'] || data[:email])
        return render json: { error: 'Email already exists' }, status: :unprocessable_entity
      end

      data['role'] ||= 'user'
      data['preferences'] = { 'budget' => 0, 'usage' => '' }

      data['password_hash'] = BCrypt::Password.create(password).to_s
      data['createdAt'] = Time.now.utc.iso8601
      data['updatedAt'] = Time.now.utc.iso8601

      doc_ref = USERS_COLLECTION.add(data)
      render json: clean_user_data(data, doc_ref.document_id), status: :created
    rescue => e
      Rails.logger.error "REGISTER ERROR: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: 'Internal server error', detail: e.message }, status: :internal_server_error
    end
  end

  private

  def authorize_request
    header = request.headers['Authorization']
    decoded = decode_token(header, SECRET_KEY)
    if decoded
      @current_user_id = decoded['user_id']
      @current_user_email = decoded['email']
    else
      render json: { error: 'Invalid or missing token' }, status: :unauthorized
    end
  end

  def authorize_admin
    header = request.headers['Authorization']
    user_doc = current_user(header, SECRET_KEY)
    unless user_doc && user_role(user_doc) == 'admin'
      render json: { error: 'Admin privileges required' }, status: :forbidden
    end
  end

  def user_params
    params.permit(:name, :email, :role, :password)
  end
end
