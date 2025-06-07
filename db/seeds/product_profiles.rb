# Script para crear perfiles de productos de ejemplo

def create_sample_product_profiles
  # Obtener algunos productos existentes
  products = PRODUCTS_COLLECTION.limit(5).get
  
  products.each do |product_doc|
    product = product_doc.data
    product_id = product_doc.document_id
    
    # Verificar si ya existe un perfil
    existing = PRODUCT_PROFILES_COLLECTION.where('product_id', '==', product_id).get
    next if existing.any?
    
    # Crear perfil basado en el nombre del producto
    product_name = product['name']&.downcase || ''
    
    profile_data = {
      'product_id' => product_id,
      'target_usage' => determine_target_usage(product_name),
      'price_range' => determine_price_range(product['price']),
      'recommended_experience' => ['beginner', 'intermediate', 'advanced'],
      'strengths' => determine_strengths(product_name),
      'form_factor' => determine_form_factor(product_name, product['category']),
      'gaming_performance' => determine_gaming_performance(product_name),
      'software_compatibility' => determine_software_compatibility(product_name),
      'createdAt' => Time.now.utc.iso8601,
      'updatedAt' => Time.now.utc.iso8601
    }
    
    PRODUCT_PROFILES_COLLECTION.add(profile_data)
    puts "Created profile for: #{product['name']}"
  end
end

def determine_target_usage(product_name)
  usage = []
  
  if product_name.include?('gaming')
    usage << 'gaming'
    usage << 'mixed'
  end
  
  if product_name.include?('business') || product_name.include?('professional')
    usage << 'work'
  end
  
  if product_name.include?('student') || product_name.include?('education')
    usage << 'study'
  end
  
  # Default si no se encuentra nada específico
  usage << 'mixed' if usage.empty?
  
  usage.uniq
end

def determine_price_range(price)
  price_f = price.to_f
  
  case price_f
  when 0..500
    'low'
  when 501..1200
    'medium'
  when 1201..2500
    'high'
  else
    'unlimited'
  end
end

def determine_strengths(product_name)
  strengths = []
  
  if product_name.include?('gaming') || product_name.include?('rtx') || product_name.include?('performance')
    strengths << 'performance'
  end
  
  if product_name.include?('budget') || product_name.include?('affordable')
    strengths << 'price'
  end
  
  if product_name.include?('slim') || product_name.include?('design') || product_name.include?('premium')
    strengths << 'design'
  end
  
  # Default
  strengths << 'reliability' if strengths.empty?
  
  strengths.uniq
end

def determine_form_factor(product_name, category)
  return 'laptop' if category&.downcase == 'laptops'
  return 'desktop' if category&.downcase == 'desktops'
  
  if product_name.include?('laptop') || product_name.include?('notebook')
    'laptop'
  elsif product_name.include?('desktop') || product_name.include?('tower')
    'desktop'
  else
    'either'
  end
end

def determine_gaming_performance(product_name)
  if product_name.include?('rtx 4090') || product_name.include?('rtx 4080') || product_name.include?('hardcore')
    'hardcore'
  elsif product_name.include?('gaming') || product_name.include?('rtx') || product_name.include?('geforce')
    'regular'
  elsif product_name.include?('gtx') || product_name.include?('entry')
    'casual'
  else
    'not-suitable'
  end
end

def determine_software_compatibility(product_name)
  software = ['web', 'office'] # Base para todos
  
  if product_name.include?('gaming')
    software += ['gaming', 'streaming']
  end
  
  if product_name.include?('creator') || product_name.include?('design')
    software += ['design', 'video', '3d']
  end
  
  if product_name.include?('developer') || product_name.include?('pro')
    software += ['programming', 'design']
  end
  
  if product_name.include?('workstation')
    software += ['programming', '3d', 'video']
  end
  
  software.uniq
end

# Ejecutar el script
# create_sample_product_profiles