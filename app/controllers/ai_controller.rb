class AiController < ApplicationController
  def recommendations
    answers = params[:answers]
    return render json: { error: 'answers is required' }, status: :bad_request unless answers.present?

    answers = answers.to_unsafe_h if answers.is_a?(ActionController::Parameters)

    # Obtén todos los productos
    products = PRODUCTS_COLLECTION.get.map(&:data)

    # Prepara el prompt para Gemini
    prompt = <<~PROMPT
      Eres un asistente experto en recomendar productos. 
      Estas son las respuestas del usuario:
      #{answers.map { |k, v| "#{k}: #{v}" }.join("\n")}

      Estos son los productos disponibles (en formato JSON):
      #{products.to_json}

      Basado en las respuestas del usuario y los productos, recomienda el producto más adecuado y explica brevemente por qué.
      Devuelve solo un objeto JSON con el producto recomendado y una explicación, por ejemplo:
      {
        "product": { ... },
        "reason": "..."
      }
    PROMPT

    gemini = GeminiSuggestionsService.new

    response = gemini.client.generate_content(prompt)
    begin
      recommendation = JSON.parse(response.text)
      render json: recommendation
    rescue
      render json: { error: 'Error parsing Gemini response', raw: response.text }, status: :unprocessable_entity
    end
  end
end
