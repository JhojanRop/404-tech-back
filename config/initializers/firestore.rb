require "google/cloud/firestore"
require 'json'

SECRET_KEY = Rails.application.secret_key_base || ENV['SECRET_KEY_BASE']

# credentials_path = File.expand_path(ENV['GOOGLE_APPLICATION_CREDENTIALS'], __dir__)

FIRESTORE = Google::Cloud::Firestore.new(
  project_id: ENV['FIREBASE_PROJECT_ID'],
  credentials: ENV['GOOGLE_APPLICATION_CREDENTIALS']
)
PRODUCTS_COLLECTION = FIRESTORE.col('products')
USERS_COLLECTION = FIRESTORE.col('users')
RECOMMENDATIONS_COLLECTION = FIRESTORE.col('recommendations')
ORDERS_COLLECTION = FIRESTORE.col('orders')
DISCOUNTS_COLLECTION = FIRESTORE.col('discounts')
