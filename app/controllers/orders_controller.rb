require Rails.root.join('app', 'utils', 'auth_utils.rb')

class OrdersController < ApplicationController
  include AuthUtils

  before_action :authorize_admin_editor_or_support!, only: [:update, :destroy] # Quitar :create

  # GET /orders
  def index
    if params[:user_id].present?
      filtered_orders = ORDERS_COLLECTION.where(:userID, "==", params[:user_id]).get.map { |doc| doc.data.merge(id: doc.document_id) }
      render json: { orders: filtered_orders, total: filtered_orders.size }
    else
      all_orders = ORDERS_COLLECTION.get.map { |doc| doc.data.merge(id: doc.document_id) }
      render json: { orders: all_orders, total: all_orders.size }
    end
  end

  # GET /orders/:id
  def show
    doc = ORDERS_COLLECTION.doc(params[:id]).get
    if doc.exists?
      order = doc.data.merge(id: doc.document_id)
      render json: order
    else
      render json: { error: "Order not found" }, status: :not_found
    end
  end

  # POST /orders
  def create
    attrs = order_params.to_h.symbolize_keys
    attrs[:status] = "paid" # Forzar status
    @order = Order.new(attrs)
    if @order.valid?
      doc_ref = ORDERS_COLLECTION.add(@order.to_firestore_hash)
      render json: @order.as_json.merge(id: doc_ref.document_id), status: :created
    else
      render json: { error: @order.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PUT /orders/:id
  def update
    doc = ORDERS_COLLECTION.doc(params[:id])
    if doc.get.exists?
      @order = Order.new(order_params.to_h.symbolize_keys)
      if @order.valid?
        doc.update(@order.to_firestore_hash)
        updated_order = doc.get.data.merge(id: doc.document_id)
        render json: updated_order
      else
        render json: { error: @order.errors.full_messages }, status: :unprocessable_entity
      end
    else
      render json: { error: "Order not found" }, status: :not_found
    end
  end

  # DELETE /orders/:id
  def destroy
    doc = ORDERS_COLLECTION.doc(params[:id])
    if doc.get.exists?
      doc.delete
      head :no_content
    else
      render json: { error: "Order not found" }, status: :not_found
    end
  end

  private

  def order_params
    params.permit(
      :user_id, :status, :total, :created_at,
      products: [:productID, :price, :quantity],
      shipping: [:address, :city, :state, :zipcode]
    )
  end

  def authorize_admin_editor_or_support!
    header = request.headers['Authorization']
    secret_key = Rails.application.credentials.secret_key_base || ENV['SECRET_KEY_BASE']
    user_doc = current_user(header, secret_key)
    unless user_doc && ['admin', 'editor', 'support'].include?(user_role(user_doc))
      render json: { error: 'Admin, editor or support privileges required' }, status: :forbidden and return
    end
  end
end
