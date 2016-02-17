class Place

  attr_accessor :id
  attr_accessor :formatted_address
  attr_accessor :location
  attr_accessor :address_components

  def initialize(params)
    @id = params[:_id].to_s
    @formatted_address = params[:formatted_address]
    @location = Point.new(params[:geometry][:geolocation])
    @address_components = []

    if params.key?(:address_components)
      params[:address_components].each do |address_component|
        @address_components << AddressComponent.new(address_component)
      end
    end
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    self.mongo_client[:places]
  end

  def self.load_all(file)
    self.collection.insert_many(JSON.parse(file.read))
  end

  def self.find_by_short_name(short_name)
    self.collection.find({"address_components.short_name" => short_name})
  end

  def self.to_places(places)
    places.map { |place| Place.new(place) }
  end

  def self.find(id)
    place = self.collection.find({_id: BSON::ObjectId.from_string(id)}).first
    Place.new(place) unless place.nil?
  end

  def self.all(offset = 0, limit = 0)
    places = self.collection.find.skip(offset).limit(limit)
    self.to_places(places)
  end

end
