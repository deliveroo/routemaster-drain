require 'spec_helper'
require 'routemaster/resources/rest_resource'

module Routemaster
  module Resources
    RSpec.describe RestResource do
      let(:url) { 'test_url' }
      let(:client) { double('Client') }
      let(:params) { {} }

      subject { described_class.new(url, client: client) }

      describe '#create' do
        it 'posts to the given url' do
          expect(client).to receive(:post).with(url, body: params)
          subject.create(params)
        end
      end

      describe '#show' do
        it 'gets to the given url' do
          expect(client).to receive(:get).with(url)
          subject.show
        end
      end

      describe '#index' do
        it 'gets to the given url' do
          expect(client).to receive(:get).with(url)
          subject.index
        end
      end
    end
  end
end
