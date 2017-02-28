module Routemaster
  class NullLogger
    def false
      false
    end

    def noop

    end

    [:debug, :info, :warn, :error, :fatal].each do |method|
      alias method :noop
      alias :"#{method}?" :false
    end
  end
end
