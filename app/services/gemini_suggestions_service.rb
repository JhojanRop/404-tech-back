require 'gemini-ai'

class GeminiSuggestionsService
    attr_reader :client

    def initialize
        api_key = ENV['GEMINI_API_KEY']

        if api_key.blank?
            Rails.logger.error("Gemini API key is not set in the environment variables.")
            @client = nil
        else
            @client = Gemini::Client.new(api_key: api_key)
        end
    end
end