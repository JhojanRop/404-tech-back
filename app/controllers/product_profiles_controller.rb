require Rails.root.join('app', 'utils', 'auth_utils.rb')

class ProductProfilesController < ApplicationController
  include AuthUtils

  before_action :authorize_request
  before_action :authorize_admin_or_editor, except: [:show, :index]

  # GET /product_profiles
  def index
    profiles = PRODUCT_PROFILES_COLLECTION.get.map do |doc|
      doc.data.merge(id: doc.document_id)
    end
    render json: profiles
  end

  # GET /product_profiles/:id
  def show
    doc = PRODUCT_PROFILES_COLLECTION.doc(params[:id]).get
    if doc.exists?
      profile = doc.data.merge(id: doc.document_id)
      render json: profile
    else
      render json: { error: 'Product profile not found' }, status: :not_found
    end
  end

  # POST /product_profiles
  def create
    begin
      data = product_profile_params.to_h
      
      # Validar que el producto existe
      unless product_exists?(data['product_id'])
        return render json: { error: 'Product not found' }, status: :not_found
      end

      # Verificar si ya existe un perfil para este producto
      if profile_exists_for_product?(data['product_id'])
        return render json: { error: 'Product profile already exists' }, status: :conflict
      end

      data['createdAt'] = Time.now.utc.iso8601
      data['updatedAt'] = Time.now.utc.iso8601

      doc_ref = PRODUCT_PROFILES_COLLECTION.add(data)
      profile = data.merge(id: doc_ref.document_id)
      
      render json: profile, status: :created
    rescue => e
      Rails.logger.error "CREATE PRODUCT PROFILE ERROR: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: 'Internal server error', detail: e.message }, status: :internal_server_error
    end
  end

  # PUT /product_profiles/:id
  def update
    doc = PRODUCT_PROFILES_COLLECTION.doc(params[:id])
    if doc.get.exists?
      begin
        data = product_profile_params.to_h
        data['updatedAt'] = Time.now.utc.iso8601
        
        doc.update(data)
        updated_profile = doc.get.data.merge(id: doc.document_id)
        
        render json: updated_profile
      rescue => e
        Rails.logger.error "UPDATE PRODUCT PROFILE ERROR: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
        render json: { error: 'Internal server error', detail: e.message }, status: :internal_server_error
      end
    else
      render json: { error: 'Product profile not found' }, status: :not_found
    end
  end

  # DELETE /product_profiles/:id
  def destroy
    doc = PRODUCT_PROFILES_COLLECTION.doc(params[:id])
    if doc.get.exists?
      doc.delete
      head :no_content
    else
      render json: { error: 'Product profile not found' }, status: :not_found
    end
  end

  private

  def authorize_request
    header = request.headers['Authorization']
    secret_key = Rails.application.credentials.secret_key_base || ENV['SECRET_KEY_BASE']
    decoded = decode_token(header, secret_key)
    unless decoded
      render json: { error: 'Invalid or missing token' }, status: :unauthorized
    end
  end

  def authorize_admin_or_editor
    header = request.headers['Authorization']
    secret_key = Rails.application.credentials.secret_key_base || ENV['SECRET_KEY_BASE']
    user_doc = current_user(header, secret_key)
    unless user_doc && ['admin', 'editor'].include?(user_role(user_doc))
      render json: { error: 'Admin or editor privileges required' }, status: :forbidden
    end
  end

  def product_profile_params
    params.permit(:product_id, :price_range, :form_factor, :gaming_performance,
                 target_usage: [], recommended_experience: [], strengths: [], 
                 software_compatibility: [])
  end

  def product_exists?(product_id)
    return false unless product_id.present?
    PRODUCTS_COLLECTION.doc(product_id).get.exists?
  end

  def profile_exists_for_product?(product_id)
    return false unless product_id.present?
    PRODUCT_PROFILES_COLLECTION.where('product_id', '==', product_id).get.any?
  end
end