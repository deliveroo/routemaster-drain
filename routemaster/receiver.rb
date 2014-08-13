require 'routemaster/receiver/basic'

module Routemaster
  module Receiver
    def self.new(*arg)
      warn 'using Routemaster::Receiver directly is deprecated, use Routemaster::Receiver::Basic instead'
      Basic.new(*arg)
    end
  end
end
