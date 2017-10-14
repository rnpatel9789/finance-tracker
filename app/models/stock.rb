class Stock < ActiveRecord::Base
  has_many :user_stocks
  has_many :users, through: :user_stocks

  def self.find_by_ticker(ticker_symbol)
    where(ticker: ticker_symbol).first
  end

  def self.new_from_lookup(ticker_symbol)
    looked_up_stock = Stock.api_lookup(ticker_symbol)
    return nil unless looked_up_stock.present?

    new_stock = new(ticker: looked_up_stock.symbol, name: looked_up_stock.name)
    new_stock.last_price = new_stock.price
    new_stock
  end

  def price
    stock_data = Stock.api_lookup(ticker)
    return 'Unavailable' unless stock_data.present?
    
    closing_price = stock_data.close
    return "#{closing_price} (Closing)" if closing_price

    opening_price = stock_data.open
    return "#{opening_price} (Opening)" if opening_price
    
    'Unavailable'
  end

  private
  
  def self.api_lookup(ticker_symbol)
    
    # The API base URL
    api_url = 'https://www.alphavantage.co/query'
    
    # API parameters
    function = "function=TIME_SERIES_DAILY"
    # interval = "interval=1min"
    symbol = "symbol=#{ticker_symbol}"
    apikey = "apikey=ESIEUJNJNPPUCCK2"
    
    # Create the api query string from the API parameters
    query = [function, symbol, apikey].join('&')
    
    # Combine the API URL and the query to get the full URL
    url = "#{api_url}?#{query}"
    
    begin # Use error handling
      # Send API request and parse JSON response.
      uri = URI(url)
      response = Net::HTTP.get(uri)
      data = JSON.parse(response)
      # puts "data: #{data}"
      # Get the actual historical data
      historical_data = data['Time Series (Daily)']
      return nil unless historical_data
      # puts "historical data: #{historical_data}"
      # Get the most recent data
      recent_data = historical_data.first
      return nil unless recent_data # Stop early if no recent data
      
      # The actual data hash is in the second item.
      recent_data = recent_data[1]
      return nil unless recent_data # Stop early if no recent data
      
      # Extract desired information into a struct to avoid hash notation.
      OpenStruct.new({
        open: recent_data['1. open'].to_f,
        close: recent_data['4. close'].to_f,
        symbol: data['Meta Data']["2. Symbol"],
      })
    # Rescue any network related errors
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
       Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
       # Add any network error handling logic here
       nil # Lookup failed, return nothing
    # Rescue JSON Parse error, likely caused by an internal issue or slow response.
    rescue JSON::ParserError => e
      nil # Lookup failed, return nothing
    end
  end
end
