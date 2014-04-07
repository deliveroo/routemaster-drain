require 'spec_helper'
require 'routemaster_client'

describe RoutemasterClient do
  describe '#initialize' do
    it 'passes with valid arguments'
    it 'fails with a non-SSL URL'
    it 'fails with a bad URL'
    it 'fails with a bad client id'
    it 'fails it it cannot connect'
  end

  shared_examples 'an event sender' do
    it 'sends the event'
    it 'fails with a bad event type'
    it 'fails with a bad callback URL'
    it 'fails with a non-SSL URL'
    it 'fails with a bad topic name'
  end

  describe '#created' do
    let(:event) { :created }
    it_behaves_like 'an event sender'
  end

  describe '#updated' do
    let(:event) { :updated }
    it_behaves_like 'an event sender'
  end

  describe '#deleted' do
    let(:event) { :deleted }
    it_behaves_like 'an event sender'
  end

  describe '#noop' do
    let(:event) { :noop }
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

