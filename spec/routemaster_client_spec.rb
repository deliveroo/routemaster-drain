require 'spec_helper'
require 'routemaster_client'
require 'webmock/rspec'

describe Routemaster::Client do
  let(:options) {{
    url:  'https://bus.example.com',
    uuid: 'john_doe'
  }}
  subject { described_class.new(options) }

  before do
    stub_request(:get, %r{^https://#{options[:uuid]}:x@bus.example.com/pulse$}).with(status: 200)
  end

  describe '#initialize' do
    it 'passes with valid arguments' do
      expect { subject }.not_to raise_error
    end

    it 'fails with a non-SSL URL' do
      options[:url].sub!(/https/, 'http')
      expect { subject }.to raise_error(ArgumentError)
    end

    it 'fails with a bad URL' do
      options[:url].replace('foobar')
      expect { subject }.to raise_error(ArgumentError)
    end

    it 'fails with a bad client id' do
      options[:uuid].replace('123 $%')
      expect { subject }.to raise_error(ArgumentError)
    end

    it 'fails it it cannot connect' do
      stub_request(:any, %r{^https://#{options[:uuid]}:x@bus.example.com}).to_raise(Faraday::ConnectionFailed)
      expect { subject }.to raise_error
    end
  end

  shared_examples 'an event sender' do
    let(:callback) { 'https://app.example.com/widgets/123' }
    
    before do
      @stub = stub_request(:post, "https://#{options[:uuid]}:x@bus.example.com/topics/widgets").with(status: 200)
    end
    
    it 'sends the event' do
      subject.send(event, 'widget', callback)
      # a_request(:post, 'https://bus.example.com/topics/widgets').
      #   with { |r|
      #     r.headers['Content-Type'] == 'application/json' &&
      #     JSON.parse(r.body) == { event: event, url: callback }
      #   }.
      #   should have_been_made
      # stub_request.should have_been_requested
    end

    it 'fails with a bad event type'
    it 'fails with a bad callback URL'
    it 'fails with a non-SSL URL'
    it 'fails with a bad topic name'
  end

  describe '#created' do
    let(:event) { 'created' }
    it_behaves_like 'an event sender'
  end

  describe '#updated' do
    let(:event) { 'updated' }
    it_behaves_like 'an event sender'
  end

  describe '#deleted' do
    let(:event) { 'deleted' }
    it_behaves_like 'an event sender'
  end

  describe '#noop' do
    let(:event) { 'noop' }
    it_behaves_like 'an event sender'
  end

  describe '#subscribe' do
    it 'passes with correct arguments'
    it 'fails with a bad callback'
    it 'fails with a bad timeout'
    it 'fails with a bad max number of events'
    it 'fails with a bad topic list'
  end

  describe '#monitor_topics' do
    it 'passes'
  end

  describe '#monitor_scubscriptions' do
    it 'passes'
  end
end

