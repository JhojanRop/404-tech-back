require Rails.root.join('app', 'utils', 'auth_utils.rb')

class DiscountCodesController < ApplicationController
  include AuthUtils

  before_action :authorize_admin_or_editor!, except: [:show]

  # GET /discount_codes
  def index
    all_discounts = DISCOUNTS_COLLECTION.get.map do |doc|
      doc_data = doc.data.slice(:amount, :code, :uses, :expiration_date)
      doc_data[:id] = doc.document_id
      doc_data
    end
    render json: { discount_codes: all_discounts, total: all_discounts.size }
  end

  # GET /discount_codes/:code
  def show
    code = params[:id].to_s.upcase
    query = DISCOUNTS_COLLECTION.where(:code, "=", code).get
    doc = query.first
    if doc&.exists?
      discount = doc.data.slice(:amount, :code, :uses, :expiration_date).merge(id: doc.document_id)
      render json: discount
    else
      render json: { error: "Discount code not found" }, status: :not_found
    end
  end

  # POST /discount_codes
  def create
    attrs = discount_code_params.to_h.symbolize_keys
    attrs[:code] = attrs[:code].to_s.upcase
    doc_ref = DISCOUNTS_COLLECTION.add(attrs)
    render json: attrs.merge(id: doc_ref.document_id), status: :created
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PUT /discount_codes/:id
  def update
    doc = DISCOUNTS_COLLECTION.doc(params[:id])
    if doc.get.exists?
      data = discount_code_params.to_h.symbolize_keys
      data[:code] = data[:code].to_s.upcase if data[:code]
      doc.update(data)
      updated_discount = doc.get.data.slice(:amount, :code, :uses, :expiration_date).merge(id: doc.document_id)
      render json: updated_discount
    else
      render json: { error: "Discount code not found" }, status: :not_found
    end
  end

  # DELETE /discount_codes/:id
  def destroy
    doc = DISCOUNTS_COLLECTION.doc(params[:id])
    if doc.get.exists?
      doc.delete
      head :no_content
    else
      render json: { error: "Discount code not found" }, status: :not_found
    end
  end

  # POST /discount_codes/:code/consume
  skip_before_action :authorize_admin_or_editor!, only: [:show, :consume]

  def consume
    doc = DISCOUNTS_COLLECTION.doc(params[:id])
    snapshot = doc.get
    if snapshot.exists?
      data = snapshot.data
      if data[:uses].to_i > 0
        doc.update({ uses: data[:uses].to_i - 1 })
        updated = doc.get.data.slice(:amount, :code, :uses, :expiration_date).merge(id: doc.document_id)
        render json: updated
      else
        render json: { error: "No uses left for this code" }, status: :unprocessable_entity
      end
    else
      render json: { error: "Discount code not found" }, status: :not_found
    end
  end

  private

  def discount_code_params
    params.require(:discount_code).permit(:amount, :code, :uses, :expiration_date)
  end
end
