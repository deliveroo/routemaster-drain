require 'core_ext/forwardable'

if RUBY_VERSION == '2.4.0'
  describe Forwardable do
    class Foo
      extend Forwardable

      def initialize
        @bar = :bar
      end

      def_delegator :@bar, :to_s, :qux
    end

    it 'expect delegation to work' do
      expect(Foo.new.qux).to eq 'bar'
    end
  end
end
