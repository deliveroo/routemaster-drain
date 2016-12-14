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
          subject.show(1)
        end
      end

      describe '#index' do
        it 'gets to the given url' do
          expect(client).to receive(:get).with(url)
          subject.index
        end
      end

      describe '#update' do
        it 'gets to the given url' do
          expect(client).to receive(:patch).with(url, body: params)
          subject.update(1, params)
        end
      end
    end
  end
end
