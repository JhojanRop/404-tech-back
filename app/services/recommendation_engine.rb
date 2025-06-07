class RecommendationEngine
  
  def self.generate_recommendations(user_profile)
    # Obtener todos los productos
    products = get_all_products
    
    # Obtener perfiles de productos (si existen)
    product_profiles = get_all_product_profiles
    
    # Calcular scores para cada producto
    scored_products = products.map do |product|
      product_profile = find_product_profile(product['id'], product_profiles)
      match_score = calculate_match_score(user_profile, product, product_profile)
      
      product.merge({
        'matchPercentage' => match_score,
        'whyRecommended' => generate_reasons(user_profile, product, product_profile, match_score)
      })
    end
    
    # Filtrar y ordenar
    recommendations = scored_products
      .select { |p| p['matchPercentage'] >= 50 } # Solo productos con 50%+ de match
      .sort_by { |p| -p['matchPercentage'] } # Ordenar por score descendente
      .first(10) # Limitar a 10 recomendaciones
    
    recommendations
  end

  private

  def self.get_all_products
    PRODUCTS_COLLECTION.get.map { |doc| doc.data.merge('id' => doc.document_id) }
  end

  def self.get_all_product_profiles
    PRODUCT_PROFILES_COLLECTION.get.map { |doc| doc.data.merge('id' => doc.document_id) }
  end

  def self.find_product_profile(product_id, product_profiles)
    product_profiles.find { |pp| pp['product_id'] == product_id }
  end

  def self.calculate_match_score(user_profile, product, product_profile = nil)
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

  def self.calculate_profile_based_score(user_profile, product_profile)
    score = 0
    
    # Compatibilidad de uso
    if product_profile['target_usage']&.include?(user_profile['usage'])
      score += 25
    end
    
    # Compatibilidad de experiencia
    if product_profile['recommended_experience']&.include?(user_profile['experience'])
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
    if product_profile['strengths']&.include?(user_profile['priority'])
      score += 15
    end
    
    score
  end

  def self.calculate_basic_score(user_profile, product)
    score = 0
    product_name = product['name']&.downcase || ''
    product_desc = product['description']&.downcase || ''
    category = product['category']&.downcase || ''
    
    # Score base por uso
    case user_profile['usage']
    when 'gaming'
      score += 30 if product_name.include?('gaming') || product_name.include?('rtx') || product_name.include?('geforce')
      score += 20 if category == 'laptops' && product_name.include?('gaming')
      score += 15 if category == 'desktops'
    when 'work'
      score += 25 if product_name.include?('business') || product_name.include?('professional')
      score += 20 if category == 'laptops'
      score += 15 if product_name.include?('intel') || product_name.include?('ryzen')
    when 'study'
      score += 20 if category == 'laptops'
      score += 15 if product['price'].to_f < 800
    when 'mixed'
      score += 15 # Score neutral
    end
    
    # Score por gaming específico
    gaming_keywords = ['gaming', 'rtx', 'geforce', 'radeon', 'rog', 'msi gaming']
    if user_profile['gaming'] != 'not-important'
      gaming_score = gaming_keywords.count { |keyword| product_name.include?(keyword) }
      
      case user_profile['gaming']
      when 'casual'
        score += [gaming_score * 5, 15].min
      when 'regular'
        score += [gaming_score * 8, 20].min
      when 'hardcore'
        score += [gaming_score * 10, 25].min
      end
    end
    
    # Score por portabilidad
    case user_profile['portability']
    when 'laptop'
      score += category == 'laptops' ? 20 : 0
    when 'desktop'
      score += category == 'desktops' ? 20 : 5
    when 'either'
      score += 10
    end
    
    score
  end

  def self.calculate_price_score(user_profile, product)
    price = product['price'].to_f
    
    case user_profile['budget']
    when 'low'
      if price <= 500
        25
      elsif price <= 800
        15
      else
        0
      end
    when 'medium'
      if price.between?(400, 1200)
        25
      elsif price.between?(300, 1500)
        15
      else
        10
      end
    when 'high'
      if price.between?(1000, 2500)
        25
      elsif price.between?(800, 3000)
        20
      else
        15
      end
    when 'unlimited'
      price > 1000 ? 25 : 20
    else
      10
    end
  end

  def self.generate_reasons(user_profile, product, product_profile, match_score)
    reasons = []
    
    # Razón general por score
    if match_score >= 90
      reasons << "Coincidencia perfecta con tus necesidades"
    elsif match_score >= 80
      reasons << "Excelente opción para tu perfil"
    elsif match_score >= 70
      reasons << "Buena opción que cumple tus requisitos"
    else
      reasons << "Opción viable para considerar"
    end
    
    # Razones específicas
    product_name = product['name']&.downcase || ''
    
    if user_profile['usage'] == 'gaming' && product_name.include?('gaming')
      reasons << "Optimizado para gaming"
    end
    
    if user_profile['budget'] == 'low' && product['price'].to_f <= 600
      reasons << "Excelente relación calidad-precio"
    end
    
    if user_profile['portability'] == 'laptop' && product['category'] == 'laptops'
      reasons << "Portátil como necesitas"
    end
    
    if user_profile['priority'] == 'performance' && (product_name.include?('rtx') || product_name.include?('gaming'))
      reasons << "Alto rendimiento"
    end
    
    if user_profile['priority'] == 'price' && product['price'].to_f < 700
      reasons << "Precio competitivo"
    end
    
    # Si hay perfil de producto específico
    if product_profile
      if product_profile['strengths']&.include?(user_profile['priority'])
        reasons << "Fortaleza en #{user_profile['priority']}"
      end
      
      common_software = (user_profile['software'] & (product_profile['software_compatibility'] || [])).size
      if common_software > 0
        reasons << "Compatible con tu software"
      end
    end
    
    reasons.uniq.first(4) # Máximo 4 razones
  end
end
