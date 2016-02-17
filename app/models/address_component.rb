class AddressComponent

  attr_reader :long_name
  attr_reader :short_name
  attr_reader :types

  def initialize(params)
    @long_name = params[:long_name]
    @short_name = params[:short_name]
    @types = params[:types]
  end

end
