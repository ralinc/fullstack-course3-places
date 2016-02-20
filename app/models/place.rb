class Place
  include ActiveModel::Model

  attr_accessor :id
  attr_accessor :formatted_address
  attr_accessor :location
  attr_accessor :address_components

  def initialize(params)
    @places = Place.collection
    @id = params[:_id].to_s
    @formatted_address = params[:formatted_address]
    @location = Point.new(params[:geometry][:geolocation])
    @address_components = []

    if params[:address_components]
      params[:address_components].each do |address_component|
        @address_components << AddressComponent.new(address_component)
      end
    end
  end

  def persisted?
    !@id.nil?
  end

  def self.mongo_client
    Mongoid::Clients.default
  end

  def self.collection
    mongo_client[:places]
  end

  def self.load_all(file)
    collection.insert_many(JSON.parse(file.read))
  end

  def self.find_by_short_name(short_name)
    collection.find({"address_components.short_name" => short_name})
  end

  def self.to_places(places)
    places.map { |place| Place.new(place) }
  end

  def self.find(id)
    place = collection.find({_id: BSON::ObjectId.from_string(id)}).first
    Place.new(place) unless place.nil?
  end

  def self.all(offset = 0, limit = 0)
    places = collection.find.skip(offset).limit(limit)
    to_places(places)
  end

  def destroy
    @places.delete_one(_id: BSON::ObjectId.from_string(@id))
  end

  def self.get_address_components(sort = nil, offset = nil, limit = nil)
    pipeline = [
      {:$unwind => "$address_components"},
      {:$project => {address_components: 1, formatted_address: 1, geometry: {geolocation: 1}}}
    ]

    pipeline << {:$sort => sort} unless sort.nil?
    pipeline << {:$skip => offset} unless offset.nil?
    pipeline << {:$limit => limit} unless limit.nil?

    collection.find.aggregate pipeline
  end

  def self.get_country_names
    collection.find.aggregate([
      {:$project => {_id: 0, address_components: {long_name: 1, types: 1}}},
      {:$unwind => "$address_components"},
      {:$unwind => "$address_components.types"},
      {:$match => {"address_components.types" => "country"}},
      {:$group => {:_id=>"$address_components.long_name"}}]).to_a.map {|h| h[:_id]}
  end

  def self.find_ids_by_country_code country_code
    collection.find.aggregate([
      {:$unwind => "$address_components"},
      {:$match => {
        "address_components.short_name" => country_code,
        "address_components.types" => "country"
        }
      },
      {:$group => {_id: "$_id"}},
      {:$project => {_id: 1}}
    ]).to_a.map {|doc| doc[:_id].to_s}
  end

  def self.create_indexes
    collection.indexes.create_one("geometry.geolocation" => Mongo::Index::GEO2DSPHERE)
  end

  def self.remove_indexes
    collection.indexes.drop_one("geometry.geolocation_2dsphere")
  end

  def self.near(point, max_meters = 0)
    collection.find('geometry.geolocation' => {:$near => {:$geometry => point, :$maxDistance => max_meters}})
  end

  def near(max_meters = 0)
    Place.to_places(Place.near(@location.to_hash, max_meters))
  end

  def photos(offset = 0, limit = 0)
    photos = Photo.find_photos_for_place(@id).skip(offset).limit(limit)
    photos.map {|photo| Photo.new(photo)}
  end

end
