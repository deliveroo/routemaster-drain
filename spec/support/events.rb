module RspecSupportEvents
  def make_event(index)
    { 'topic' => 'stuff', 'type' => 'create', 'url' => "https://example.com/stuff/#{index}", 't' => 1234 }
  end
end

RSpec.configure { |c| c.include RspecSupportEvents }


