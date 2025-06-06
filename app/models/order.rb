class Order
  include ActiveModel::Model

  attr_accessor :user_id, :products, :shipping, :status, :total, :created_at

  validates :user_id, :products, :status, :total, presence: true

  def initialize(attributes = {})
    super
    self.products ||= []
    self.shipping ||= { address: "", city: "", state: "", zipcode: "" }
    self.created_at ||= Time.now
  end

  def as_json(options = {})
    {
      userID: user_id,
      products: products,
      shipping: shipping,
      status: status,
      total: total,
      createdAt: created_at
    }
  end

  def to_firestore_hash
    as_json
  end
end