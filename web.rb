require 'sinatra/base'

module SlackCAHBot
  class Web < Sinatra::Base
    get '/' do
      'Math is good for you.'
    end
  end
end
