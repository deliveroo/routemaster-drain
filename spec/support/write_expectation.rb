RSpec::Matchers.define :write do |message|
  chain(:to) do |io|
    @io = io
  end

  match do |block|
    output =
      case io
      when :output then fake_io($stdout, &block)
      when :error  then fake_io($stderr, &block)
      else raise("Allowed values for `to` are :output and :error, got `#{io.inspect}`")
      end
    output.include? message
  end

  description do
    "write \"#{message}\" #{io_name}"
  end

  failure_message do
    "expected to #{description}"
  end

  failure_message_when_negated do
    "expected to not #{description}"
  end

  def supports_block_expectations?
    true
  end

  def fake_io(io, &block)
    original_io = io.dup
    tempfile = Tempfile.new('fake')
    io.reopen(tempfile)
    yield
    io.rewind
    return io.read
  ensure
    io.reopen(original_io)
    tempfile.unlink
  end

  # default IO is standard output
  def io
    @io ||= :output
  end

  # IO name is used for description message
  def io_name
    {:output => "standard output", :error => "standard error"}[io]
  end
end

