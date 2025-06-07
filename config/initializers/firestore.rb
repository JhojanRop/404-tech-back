require "google/cloud/firestore"
require 'json'

SECRET_KEY = Rails.application.secret_key_base || ENV['SECRET_KEY_BASE']

FIRESTORE = Google::Cloud::Firestore.new(
  project_id: ENV['FIREBASE_PROJECT_ID'],
  credentials: ENV['GOOGLE_APPLICATION_CREDENTIALS']
)

PRODUCTS_COLLECTION = FIRESTORE.col('products')
USERS_COLLECTION = FIRESTORE.col('users')
RECOMMENDATIONS_COLLECTION = FIRESTORE.col('recommendations')
ORDERS_COLLECTION = FIRESTORE.col('orders')
DISCOUNTS_COLLECTION = FIRESTORE.col('discounts')
USER_PROFILES_COLLECTION = FIRESTORE.col('user_profiles')
PRODUCT_PROFILES_COLLECTION = FIRESTORE.col('product_profiles')
RECOMMENDATION_FEEDBACK_COLLECTION = FIRESTORE.col('recommendation_feedback')
