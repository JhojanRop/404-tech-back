require Rails.root.join('app', 'utils', 'auth_utils.rb')

class RecommendationsController < ApplicationController
  include AuthUtils

  # COMENTAR esta línea para deshabilitar autenticación
  # before_action :authorize_request

  # POST /recommendations
  def create
    begin
      profile_data = recommendation_params.to_h
      
      # Validar campos requeridos
      required_fields = %w[user_id usage budget experience priority portability gaming]
      missing_fields = required_fields.select { |field| profile_data[field].blank? }
      
      if missing_fields.any?
        return render json: { error: "Missing required fields: #{missing_fields.join(', ')}" }, status: :bad_request
      end

      # Generar recomendaciones
      recommendations = generate_recommendations(profile_data)
      
      # Guardar el perfil si es necesario
      user_profile = save_user_profile_if_needed(profile_data)
      
      response = {
        products: recommendations,
        userProfile: user_profile,
        totalMatches: recommendations.size
      }
      
      render json: response, status: :created
    rescue => e
      Rails.logger.error "CREATE RECOMMENDATIONS ERROR: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: 'Internal server error', detail: e.message }, status: :internal_server_error
    end
  end

  # GET /recommendations/user/:user_id
  def show_by_user
    begin
      user_id = params[:user_id]
      
      # Buscar perfil del usuario
      profiles = USER_PROFILES_COLLECTION.where('user_id', '==', user_id).get.to_a
      
      if profiles.empty?
        return render json: { error: 'User profile not found. Create one first.' }, status: :not_found
      end
      
      user_profile = profiles.first.data.merge(id: profiles.first.document_id)
      
      # Generar recomendaciones basadas en el perfil guardado
      recommendations = generate_recommendations(user_profile)
      
      response = {
        products: recommendations,
        userProfile: user_profile,
        totalMatches: recommendations.size
      }
      
      render json: response
    rescue => e
      Rails.logger.error "GET USER RECOMMENDATIONS ERROR: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: 'Internal server error', detail: e.message }, status: :internal_server_error
    end
  end

  # POST /recommendations/feedback
  def feedback
    begin
      feedback_data = feedback_params.to_h
      feedback_data['createdAt'] = Time.now.utc.iso8601
      
      RECOMMENDATION_FEEDBACK_COLLECTION.add(feedback_data)
      
      render json: { message: 'Feedback received successfully' }, status: :created
    rescue => e
      Rails.logger.error "FEEDBACK ERROR: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      render json: { error: 'Internal server error', detail: e.message }, status: :internal_server_error
    end
  end

  private

  # COMENTAR todo este método para deshabilitar autenticación
  # def authorize_request
  #   header = request.headers['Authorization']
  #   secret_key = Rails.application.credentials.secret_key_base || ENV['SECRET_KEY_BASE']
  #   decoded = decode_token(header, secret_key)
  #   unless decoded
  #     render json: { error: 'Invalid or missing token' }, status: :unauthorized
  #   end
  # end

  def recommendation_params
    params.permit(:user_id, :usage, :budget, :experience, :priority, :portability, :gaming, software: [])
  end

  def feedback_params
    params.permit(:user_id, :product_id, :recommendation_id, :feedback_type, :rating, :comment)
  end

  def generate_recommendations(user_profile)
    begin
      Rails.logger.info "=== STARTING RECOMMENDATIONS GENERATION ==="
      Rails.logger.info "User profile: #{user_profile.inspect}"
      
      # Obtener todos los productos
      products_query = PRODUCTS_COLLECTION.get
      Rails.logger.info "Firestore query executed, got #{products_query.to_a.size} documents"
      
      products = products_query.to_a.map do |doc|
        doc_data = doc.data
        doc_id = doc.document_id
        
        # SOLUCIÓN: Convertir todas las keys de símbolos a strings
        product = doc_data.transform_keys(&:to_s).merge('id' => doc_id)
        
        Rails.logger.info "Product processed: '#{product['name']}'"
        product
      end
      
      Rails.logger.info "Found #{products.size} products total"
      
      # Filtrar productos que tengan al menos nombre
      valid_products = products.select do |product|
        name = product['name']
        name_present = name.present?
        
        Rails.logger.info "Product validation: '#{name}' - present?: #{name_present}"
        name_present
      end
      
      Rails.logger.info "Valid products: #{valid_products.size}"
      
      # Si no hay productos válidos, retornar vacío
      return [] if valid_products.empty?
      
      # Obtener perfiles de productos (si existen)
      product_profiles = PRODUCT_PROFILES_COLLECTION.get.to_a.map { |doc| doc.data.transform_keys(&:to_s).merge('id' => doc.document_id) }
      
      # Calcular scores para cada producto válido
      scored_products = valid_products.map do |product|
        product_profile = find_product_profile(product['id'], product_profiles)
        match_score = calculate_match_score(user_profile, product, product_profile)
        
        Rails.logger.info "Product: '#{product['name']}', Score: #{match_score}"
        
        product.merge({
          'matchPercentage' => match_score,
          'whyRecommended' => generate_reasons(user_profile, product, product_profile, match_score)
        })
      end
      
      # Filtrar y ordenar
      recommendations = scored_products
        .select { |p| p['matchPercentage'] >= 15 }
        .sort_by { |p| -p['matchPercentage'] }
        .first(10)
      
      Rails.logger.info "Found #{recommendations.size} recommendations with score >= 15%"
      Rails.logger.info "Top recommendations: #{recommendations.first(3).map { |p| "#{p['name']} (#{p['matchPercentage']}%)" }}"
      
      recommendations
      
    rescue => e
      Rails.logger.error "Error generating recommendations: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      []
    end
  end

  # Método alternativo para obtener productos
  def get_products_alternative_method
    begin
      Rails.logger.info "=== ALTERNATIVE METHOD WITH SYMBOL FIX ==="
      
      products_query = PRODUCTS_COLLECTION.get
      products = products_query.map do |doc|
        # SOLUCIÓN: Convertir símbolos a strings
        doc.data.transform_keys(&:to_s).merge('id' => doc.document_id)
      end
      
      Rails.logger.info "Alternative method: Found #{products.size} products"
      products.each_with_index do |product, index|
        Rails.logger.info "Product #{index}: '#{product['name']}'"
      end
      
      products.select { |p| p['name'].present? }
    rescue => e
      Rails.logger.error "Alternative method failed: #{e.message}"
      []
    end
  end

  # Método para acceso directo a Firestore
  def try_direct_firestore_access
    begin
      Rails.logger.info "=== TRYING DIRECT FIRESTORE ACCESS ==="
      
      # Intentar obtener un producto específico directamente
      all_docs = PRODUCTS_COLLECTION.get.to_a
      
      if all_docs.any?
        first_doc = all_docs.first
        Rails.logger.info "First document ID: #{first_doc.document_id}"
        Rails.logger.info "First document data: #{first_doc.data.inspect}"
        
        # Intentar obtener este documento específico por ID
        specific_doc = PRODUCTS_COLLECTION.doc(first_doc.document_id).get
        Rails.logger.info "Direct doc access - exists?: #{specific_doc.exists?}"
        if specific_doc.exists?
          Rails.logger.info "Direct doc data: #{specific_doc.data.inspect}"
          Rails.logger.info "Direct doc name: '#{specific_doc.data['name']}'"
        end
      end
      
      # Retornar array vacío para debugging
      []
    rescue => e
      Rails.logger.error "Direct Firestore access failed: #{e.message}"
      []
    end
  end

  def find_product_profile(product_id, product_profiles)
    product_profiles.find { |pp| pp['product_id'] == product_id }
  end

  def calculate_match_score(user_profile, product, product_profile = nil)
    score = 0
    
    # Si hay perfil específico del producto, usarlo
    if product_profile
      score += calculate_profile_based_score(user_profile, product_profile)
    else
      # Fallback al algoritmo básico basado en nombre/categoría
      score += calculate_basic_score(user_profile, product)
    end
    
    # Score adicional por precio
    score += calculate_price_score(user_profile, product)
    
    # Normalizar a porcentaje (0-100)
    [[score, 100].min, 0].max
  end

  def calculate_profile_based_score(user_profile, product_profile)
    score = 0
    
    # Compatibilidad de uso
    target_usage = product_profile['target_usage'] || []
    if target_usage.include?(user_profile['usage'])
      score += 25
    end
    
    # Compatibilidad de experiencia
    recommended_exp = product_profile['recommended_experience'] || []
    if recommended_exp.include?(user_profile['experience'])
      score += 20
    end
    
    # Compatibilidad de gaming
    user_gaming = user_profile['gaming']
    product_gaming = product_profile['gaming_performance']
    
    case user_gaming
    when 'not-important'
      score += 15 # Neutral para cualquier producto
    when 'casual'
      score += product_gaming == 'casual' ? 20 : 10
    when 'regular'
      score += ['casual', 'regular'].include?(product_gaming) ? 20 : 5
    when 'hardcore'
      score += product_gaming == 'hardcore' ? 25 : 0
    end
    
    # Compatibilidad de software
    user_software = user_profile['software'] || []
    product_software = product_profile['software_compatibility'] || []
    
    common_software = (user_software & product_software).size
    if common_software > 0
      score += [common_software * 5, 20].min # Máximo 20 puntos por software
    end
    
    # Compatibilidad de fortalezas con prioridades
    strengths = product_profile['strengths'] || []
    if strengths.include?(user_profile['priority'])
      score += 15
    end
    
    score
  end

  def calculate_basic_score(user_profile, product)
    score = 20 # Score base para todos los productos
    
    # Validar que el producto tenga nombre
    product_name = product['name'].to_s.downcase
    if product_name.blank?
      Rails.logger.warn "Product has no name: #{product.inspect}"
      return score
    end
    
    # Manejar category de forma más robusta
    categories = case product['category']
                  when Array
                    product['category'].compact.reject(&:blank?).map(&:downcase)
                  when String
                    [product['category'].downcase].reject(&:blank?)
                  else
                    []
                  end
    
    # Si no hay categorías válidas, inferir del nombre
    if categories.empty?
      Rails.logger.info "No valid categories, inferring from name: '#{product_name}'"
      categories = infer_categories_from_name(product_name)
    end
    
    category_string = categories.join(' ')
    
    Rails.logger.info "Calculating basic score for: '#{product['name']}'"
    Rails.logger.info "Processed categories: #{categories}, User usage: #{user_profile['usage']}"
    
    # Detectar tipo de producto
    is_desktop = categories.any? { |cat| cat.include?('gaming desktop') || cat.include?('gaming & vr') || cat.include?('desktop pc') }
    is_laptop = categories.any? { |cat| cat.include?('gaming pcs') || cat.include?('computer systems') } && product_name.include?('laptop')
    is_monitor = categories.any? { |cat| cat.include?('monitor') }
    is_peripheral = categories.any? { |cat| cat.include?('input device') || cat.include?('peripherals') }
    
    # Inferir tipo si las categorías no son claras
    if !is_desktop && !is_laptop && !is_monitor && !is_peripheral
      is_laptop = product_name.include?('laptop')
      is_desktop = product_name.include?('desktop') || product_name.include?('gaming pc')
      is_monitor = product_name.include?('monitor') || product_name.include?('display')
      is_peripheral = product_name.include?('keyboard') || product_name.include?('mouse')
    end
    
    Rails.logger.info "Product type - Desktop: #{is_desktop}, Laptop: #{is_laptop}, Monitor: #{is_monitor}, Peripheral: #{is_peripheral}"
    
    # Score base por uso
    case user_profile['usage']
    when 'gaming'
      # Gaming keywords en nombre
      gaming_keywords = ['gaming', 'rtx', 'geforce', 'radeon', 'rog', 'msi', 'asus', 'acer nitro', 'abs', 'xidax', 'ibuypower']
      gaming_matches = gaming_keywords.count { |keyword| product_name.include?(keyword) }
      
      if gaming_matches > 0
        score += 25
        Rails.logger.info "Gaming name bonus: +25 (matches: #{gaming_matches})"
      end
      
      # Bonus por tipo de producto gaming
      if is_desktop
        score += 30
        Rails.logger.info "Gaming desktop bonus: +30"
      elsif is_laptop 
        score += 25
        Rails.logger.info "Gaming laptop bonus: +25"
      elsif is_peripheral
        score += 15
        Rails.logger.info "Gaming peripheral bonus: +15"
      elsif is_monitor
        score += 20
        Rails.logger.info "Gaming monitor bonus: +20"
      end
      
    when 'work'
      if is_laptop
        score += 25
      elsif is_monitor
        score += 20
      elsif is_peripheral
        score += 10
      end
      
    when 'study'
      if is_laptop
        score += 20
      elsif product['price'].to_f < 1000
        score += 15
      end
      
    when 'mixed'
      score += 15
    end
    
    # Score por gaming específico
    if user_profile['gaming'] != 'not-important'
      # Detectar nivel de gaming por specs/nombre
      high_end_gaming = product_name.include?('rtx 5080') || product_name.include?('rtx 5070') || 
                        product_name.include?('9800x3d') || product_name.include?('285k') ||
                        product_name.include?('9070xt')
      mid_gaming = product_name.include?('rtx 4060') || product_name.include?('rtx 4050') || 
                   product_name.include?('rtx 5060')
      entry_gaming = product_name.include?('vega') || product_name.include?('5600gt')
      
      case user_profile['gaming']
      when 'casual'
        if entry_gaming || mid_gaming
          score += 15
          Rails.logger.info "Casual gaming match: +15"
        end
      when 'regular'
        if mid_gaming || high_end_gaming
          score += 20
          Rails.logger.info "Regular gaming match: +20"
        end
      when 'hardcore'
        if high_end_gaming
          score += 25
          Rails.logger.info "Hardcore gaming match: +25"
        elsif mid_gaming
          score += 15
        end
      end
    end
    
    # Score por portabilidad
    case user_profile['portability']
    when 'laptop'
      if is_laptop
        score += 25
        Rails.logger.info "Laptop portability perfect match: +25"
      elsif is_desktop
        score += 2 # Penalty muy pequeña
        Rails.logger.info "Desktop penalty for laptop user: +2"
      elsif is_peripheral || is_monitor
        score += 10 # Complementarios para laptop
        Rails.logger.info "Complementary for laptop: +10"
      end
    when 'desktop'
      if is_desktop
        score += 25
        Rails.logger.info "Desktop portability perfect match: +25"
      elsif is_laptop
        score += 2 # Penalty muy pequeña
      elsif is_peripheral || is_monitor
        score += 15 # Muy útiles para desktop
      end
    when 'either'
      if is_desktop || is_laptop
        score += 20
      elsif is_peripheral || is_monitor
        score += 15
      end
    end
    
    Rails.logger.info "Total basic score for '#{product['name']}': #{score}"
    score
  end

  # Método auxiliar para inferir categorías del nombre
  def infer_categories_from_name(product_name)
    categories = []
    
    if product_name.include?('laptop')
      categories << 'computer systems'
      categories << 'gaming pcs' if product_name.include?('gaming')
    elsif product_name.include?('desktop') || product_name.include?('gaming pc')
      categories << 'gaming desktop pc'
      categories << 'gaming & vr'
    elsif product_name.include?('keyboard') || product_name.include?('mouse')
      categories << 'computer peripherals'
      categories << 'input device'
    elsif product_name.include?('monitor') || product_name.include?('display')
      categories << 'monitor'
    end
    
    categories
  end

  def calculate_price_score(user_profile, product)
    price = product['price'].to_f
    
    case user_profile['budget']
    when 'low'
      if price <= 500
        25
      elsif price <= 800
        20
      elsif price <= 1000
        10
      else
        5
      end
    when 'medium'
      if price.between?(600, 1500)
        25
      elsif price.between?(400, 2000)
        20
      elsif price.between?(300, 2500)
        15
      else
        8
      end
    when 'high'
      if price.between?(1500, 3000)
        25
      elsif price.between?(1200, 4000)
        20
      else
        15
      end
    when 'unlimited'
      if price > 1500
        25
      elsif price > 1000
        20
      else
        15
      end
    else
      15
    end
  end

  def generate_reasons(user_profile, product, product_profile, match_score)
    reasons = []
    product_name = product['name']&.downcase || ''
    categories = if product['category'].is_a?(Array)
                   product['category'].map(&:downcase)
                 else
                   [product['category']&.downcase || '']
                 end
    
    # Razón general por score
    if match_score >= 80
      reasons << "Excelente match con tu perfil"
    elsif match_score >= 60
      reasons << "Buena opción para tus necesidades"
    elsif match_score >= 40
      reasons << "Opción viable a considerar"
    else
      reasons << "Producto disponible"
    end
    
    # Razones específicas por gaming
    if user_profile['usage'] == 'gaming'
      if product_name.include?('rtx 5080') || product_name.include?('rtx 5070')
        reasons << "Gráficos de última generación"
      elsif product_name.include?('rtx 4060') || product_name.include?('rtx 4050')
        reasons << "Excelente rendimiento gaming"
      end
      
      if product_name.include?('9800x3d') || product_name.include?('285k')
        reasons << "Procesador gaming de élite"
      end
      
      if product_name.include?('32gb')
        reasons << "RAM abundante para multitarea"
      end
      
      if product_name.include?('144hz')
        reasons << "Pantalla gaming fluida"
      end
    end
    
    # Razones por presupuesto
    price = product['price'].to_f
    case user_profile['budget']
    when 'low'
      if price < 600
        reasons << "Precio muy accesible"
      end
    when 'medium'
      if price.between?(800, 1500)
        reasons << "Precio equilibrado"
      end
    when 'high'
      if price > 1500
        reasons << "Componentes premium"
      end
    end
    
    # Razones por portabilidad
    if user_profile['portability'] == 'laptop' && product_name.include?('laptop')
      reasons << "Portátil como necesitas"
    elsif user_profile['portability'] == 'desktop' && categories.any? { |cat| cat.include?('gaming desktop') }
      reasons << "Desktop de alto rendimiento"
    end
    
    # Razones por marcas
    if product_name.include?('msi') || product_name.include?('asus')
      reasons << "Marca gaming reconocida"
    elsif product_name.include?('abs') || product_name.include?('xidax')
      reasons << "PC pre-construida confiable"
    elsif product_name.include?('razer')
      reasons << "Periférico gaming premium"
    end
    
    # Razones por especificaciones
    if product_name.include?('nvme') || product_name.include?('ssd')
      reasons << "Almacenamiento ultrarrápido"
    end
    
    if product_name.include?('wifi 6') || product_name.include?('wifi 6e')
      reasons << "Conectividad moderna"
    end
    
    if product_name.include?('rgb')
      reasons << "Iluminación gaming"
    end
    
    reasons.uniq.first(4)
  end

  def save_user_profile_if_needed(profile_data)
    existing_profiles = USER_PROFILES_COLLECTION.where('user_id', '==', profile_data['user_id']).get.to_a
    
    if existing_profiles.empty?
      profile_data['createdAt'] = Time.now.utc.iso8601
      profile_data['updatedAt'] = Time.now.utc.iso8601
      
      doc_ref = USER_PROFILES_COLLECTION.add(profile_data)
      profile_data.merge('id' => doc_ref.document_id)
    else
      existing_profiles.first.data.merge('id' => existing_profiles.first.document_id)
    end
  end
end