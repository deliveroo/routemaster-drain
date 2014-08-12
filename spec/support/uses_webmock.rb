require 'webmock/rspec'

module RspecSupportUsesWebmock
  def uses_webmock
    before(:all) { WebMock.enable! }
    after(:all)  { WebMock.disable! }
  end
end

RSpec.configure { |c| c.extend RspecSupportUsesWebmock }
WebMock.disable!

