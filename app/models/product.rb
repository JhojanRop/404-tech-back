class Product
  attr_accessor :id, :name, :description, :price, :discount, :stock,
                :category, :rating, :usage, :images, :specs, :created_at

  def initialize(attributes = {})
    @id = attributes[:id]
    @name = attributes.fetch(:name) { raise ArgumentError, "name es obligatorio" }
    @price = attributes.fetch(:price) { raise ArgumentError, "price es obligatorio" }
    @category = attributes.fetch(:category) { raise ArgumentError, "category es obligatorio" }
    @rating = attributes.fetch(:rating) { 0.0 }

    @description = attributes[:description] || ""
    @discount = attributes[:discount] || 0
    @stock = attributes[:stock] || 0

    @usage = attributes[:usage] || []
    @images = attributes[:images] || []
    @specs = attributes[:specs] || {}

    @created_at = attributes[:created_at] || Time.now
  end
end
