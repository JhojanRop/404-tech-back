require Rails.root.join('app', 'utils', 'auth_utils.rb')

class ProductsController < ApplicationController
  include AuthUtils

  before_action :authorize_admin_or_editor!, only: [:create, :update, :destroy]

  # GET /products
  def index
    page = params[:page].to_i > 0 ? params[:page].to_i : 1
    limit = params[:limit].to_i > 0 ? params[:limit].to_i : 20
    sort = params[:sort].to_s
    categories_filter = params[:categories] # Puede ser un string o array
    
    all_products = PRODUCTS_COLLECTION.get.map do |doc|
      doc.data.merge(id: doc.document_id)
    end

    # Filtrado por categorías si se especifica
    if categories_filter.present?
      # Convertir a array si es un string
      filter_categories = categories_filter.is_a?(Array) ? categories_filter : [categories_filter]
      
      all_products = all_products.select do |product|
        product_categories = product[:category] || product['category']
        
        if product_categories.is_a?(Array)
          # Si las categorías del producto son un array, verificar si hay intersección
          (product_categories & filter_categories).any?
        elsif product_categories.is_a?(String)
          # Si es un string, verificar si está en los filtros
          filter_categories.include?(product_categories)
        else
          false
        end
      end
    end

    # Ordenamiento según el parámetro `sort`
    sorted_products = case sort
                    when 'best_rating'
                      all_products.sort { |a, b| ((b[:rating] || b['rating']) || 0).to_f <=> ((a[:rating] || a['rating']) || 0).to_f }
                    
                    when 'newest'
                      all_products.sort do |a, b|
                        created_a = a[:created_at] || a['created_at']
                        created_b = b[:created_at] || b['created_at']
                        timestamp_a = created_a ? Time.parse(created_a.to_s).to_i : 0
                        timestamp_b = created_b ? Time.parse(created_b.to_s).to_i : 0
                        timestamp_b <=> timestamp_a
                      end
                    
                    when 'price_low_to_high'
                      all_products.sort do |a, b|
                        price_a = a[:price] || a['price'] || 0
                        price_b = b[:price] || b['price'] || 0
                        price_a_float = price_a.is_a?(String) ? price_a.to_f : price_a.to_f
                        price_b_float = price_b.is_a?(String) ? price_b.to_f : price_b.to_f
                        price_a_float <=> price_b_float
                      end

                    when 'price_high_to_low'
                      all_products.sort do |a, b|
                        price_a = a[:price] || a['price'] || 0
                        price_b = b[:price] || b['price'] || 0
                        price_a_float = price_a.is_a?(String) ? price_a.to_f : price_a.to_f
                        price_b_float = price_b.is_a?(String) ? price_b.to_f : price_b.to_f
                        price_b_float <=> price_a_float
                      end

                    else
                      all_products
                    end

    all_products = sorted_products
    paginated_products = all_products.slice((page - 1) * limit, limit) || []

    render json: {
      products: paginated_products,
      page: page,
      limit: limit,
      total: all_products.size,
      filters: {
        categories: categories_filter
      }
    }
  end

  # GET /products/:id
  def show
    doc = PRODUCTS_COLLECTION.doc(params[:id]).get
    if doc.exists?
      product = doc.data.merge(id: doc.document_id)
      render json: product
    else
      render json: { error: "Product not found" }, status: :not_found
    end
  end

  # POST /products
  def create
    begin
      attrs = product_params.to_h.symbolize_keys
      attrs[:created_at] = Time.now

      @product = Product.new(attrs)
      # Guardar el producto en la colección (base de datos)
      doc_ref = PRODUCTS_COLLECTION.add(@product.instance_variables.each_with_object({}) do |var, hash|
        key = var.to_s.delete("@")
        hash[key] = @product.instance_variable_get(var)
      end)
      # Devolver el producto con su id generado
      render json: @product.as_json.merge(id: doc_ref.document_id), status: :created
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  # PUT /products/:id
  def update
    doc = PRODUCTS_COLLECTION.doc(params[:id])
    if doc.get.exists?
      begin
        data = product_params.to_h.symbolize_keys
        doc.update(data)
        updated_product = doc.get.data.merge(id: doc.document_id)
        render json: updated_product
      rescue => e
        render json: { error: e.message }, status: :unprocessable_entity
      end
    else
      render json: { error: "Product not found" }, status: :not_found
    end
  end

  # DELETE /products/:id
  def destroy
    doc = PRODUCTS_COLLECTION.doc(params[:id])
    if doc.get.exists?
      doc.delete
      head :no_content
    else
      render json: { error: "Product not found" }, status: :not_found
    end
  end

  # GET /products/categories
  def categories
    # Obtener todos los productos para extraer las categorías
    all_products = PRODUCTS_COLLECTION.get.map do |doc|
      doc.data
    end

    categories = []
    all_products.each do |product|
      product_categories = product[:category] || product['category']
      if product_categories.is_a?(Array)
        categories.concat(product_categories)
      elsif product_categories.is_a?(String)
        categories << product_categories
      end
    end

    unique_categories = categories.uniq.sort

    render json: {
      categories: unique_categories,
      total: unique_categories.size
    }
  end

  private

  def product_params
    params.require(:product).permit(
      :name, :description, :price, :discount, :stock, :category, :rating,
      usage: [], images: [], specs: {}
    )
  end
end
