require Rails.root.join('app', 'utils', 'auth_utils.rb')

class UserProfilesController < ApplicationController
  include AuthUtils

  before_action :authorize_request

  # GET /user_profiles
  def index
    profiles = USER_PROFILES_COLLECTION.get.map do |doc|
      doc.data.merge(id: doc.document_id)
    end
    render json: profiles
  end

  # GET /user_profiles/:id (document ID)
  def show
    doc = USER_PROFILES_COLLECTION.doc(params[:id]).get
    if doc.exists?
      profile = doc.data.merge(id: doc.document_id)
      render json: profile
    else
      render json: { error: 'User profile not found' }, status: :not_found
    end
  end

  # GET /user_profiles/by_user/:user_id
  def show_by_user
    profiles = USER_PROFILES_COLLECTION.where('user_id', '==', params[:user_id]).get.to_a
    if profiles.empty?
      render json: { error: 'User profile not found' }, status: :not_found
    else
      profile = profiles.first
      render json: profile.data.merge(id: profile.document_id)
    end
  end

  # PUT /user_profiles/by_user/:user_id
  def update_by_user
    profiles = USER_PROFILES_COLLECTION.where('user_id', '==', params[:user_id]).get.to_a
    if profiles.empty?
      render json: { error: 'User profile not found' }, status: :not_found
    else
      begin
        doc = profiles.first
        data = profile_params.to_h
        data['updatedAt'] = Time.now.utc.iso8601
        
        USER_PROFILES_COLLECTION.doc(doc.document_id).update(data)
        updated_profile = USER_PROFILES_COLLECTION.doc(doc.document_id).get.data.merge(id: doc.document_id)
        
        render json: updated_profile
      rescue => e
        Rails.logger.error "UPDATE PROFILE ERROR: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: 'Internal server error', detail: e.message }, status: :internal_server_error
      end
    end
  end

  # POST /user_profiles
  def create
    begin
      data = profile_params.to_h
      
      # Validar que el usuario existe
      unless user_exists?(data['user_id'])
        return render json: { error: 'User not found' }, status: :not_found
      end

      # Verificar si ya existe un perfil para este usuario
      if profile_exists_for_user?(data['user_id'])
        return render json: { error: 'User profile already exists' }, status: :conflict
      end

      # Validar campos requeridos
      required_fields = %w[user_id usage budget experience priority portability gaming]
      missing_fields = required_fields.select { |field| data[field].blank? }
      
      if missing_fields.any?
        return render json: { error: "Missing required fields: #{missing_fields.join(', ')}" }, status: :bad_request
      end

      # Validar arrays
      if !data['software'].is_a?(Array) || data['software'].empty?
        return render json: { error: 'Software field must be a non-empty array' }, status: :bad_request
      end

      data['createdAt'] = Time.now.utc.iso8601
      data['updatedAt'] = Time.now.utc.iso8601

      doc_ref = USER_PROFILES_COLLECTION.add(data)
      profile = data.merge(id: doc_ref.document_id)
      
      render json: profile, status: :created
    rescue => e
      Rails.logger.error "CREATE PROFILE ERROR: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: 'Internal server error', detail: e.message }, status: :internal_server_error
    end
  end

  # PUT /user_profiles/:id
  def update
    doc = USER_PROFILES_COLLECTION.doc(params[:id])
    if doc.get.exists?
      begin
        data = profile_params.to_h
        data['updatedAt'] = Time.now.utc.iso8601
        
        doc.update(data)
        updated_profile = doc.get.data.merge(id: doc.document_id)
        
        render json: updated_profile
      rescue => e
        Rails.logger.error "UPDATE PROFILE ERROR: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: 'Internal server error', detail: e.message }, status: :internal_server_error
      end
    else
      render json: { error: 'User profile not found' }, status: :not_found
    end
  end

  # DELETE /user_profiles/:id
  def destroy
    doc = USER_PROFILES_COLLECTION.doc(params[:id])
    if doc.get.exists?
      doc.delete
      head :no_content
    else
      render json: { error: 'User profile not found' }, status: :not_found
    end
  end

  private

  def authorize_request
    header = request.headers['Authorization']
    secret_key = Rails.application.credentials.secret_key_base || ENV['SECRET_KEY_BASE']
    decoded = decode_token(header, secret_key)
    if decoded
      @current_user_id = decoded['user_id']
      @current_user_email = decoded['email']
    else
      render json: { error: 'Invalid or missing token' }, status: :unauthorized
    end
  end

  def profile_params
    params.permit(:user_id, :usage, :budget, :experience, :priority, :portability, :gaming, software: [])
  end

  def user_exists?(user_id)
    return false unless user_id.present?
    USERS_COLLECTION.doc(user_id).get.exists?
  end

  def profile_exists_for_user?(user_id)
    return false unless user_id.present?
    USER_PROFILES_COLLECTION.where('user_id', '==', user_id).get.to_a.any?
  end
end