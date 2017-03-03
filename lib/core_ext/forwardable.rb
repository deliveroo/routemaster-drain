if RUBY_VERSION == '2.4.0'
  # MRI 2.4.0 has a bug in ext/rubyvm/lib/forwardable/impl.rb
  # This severaly affects gems like Faraday which extensively use delegation to
  # provide syntax sugar.
  #
  # This patch replaces it with the portable version in lib/forwardable/impl.rb
  # Source: https://bugs.ruby-lang.org/issues/13107
  require 'forwardable'
  module Forwardable
    def self._compile_method(src, file, line)
      eval(src, nil, file, line)
    end
  end
end
