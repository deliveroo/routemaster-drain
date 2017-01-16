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

      describe '#future_show' do
        it 'fgets to the given url' do
          expect(client).to receive(:fget).with(url)
          subject.future_show(1)
        end
      end

      describe '#index' do
        it 'gets to the given url' do
          expect(client).to receive(:get).with(url)
          subject.index
        end

        context 'params and filter options' do
          it 'merges the two together to call the client with' do
            expect(client).to receive(:get).with(url, params: { first_name: 'Jeff', per_page: 10 })
            subject.index(filters: { first_name: 'Jeff' }, params: { per_page: 10 })
          end
        end
      end

      describe '#future_index' do
        let(:hateoas_response) { double }

        before do
          expect(Responses::FutureEnumerableHateoasResponse).to receive(:new).with(hateoas_response)
        end

        it 'gets to the given url and constructs a future_enumerable_hateoas_response' do
          expect(client).to receive(:get).with(url) { hateoas_response }
          subject.future_index
        end

        context 'params and filter options' do
          it 'merges the two together to call the client with' do
            expect(client).to receive(:get).with(url, params: { first_name: 'Jeff', per_page: 10 }) { hateoas_response }
            subject.future_index(filters: { first_name: 'Jeff' }, params: { per_page: 10 })
          end
        end
      end

      describe '#update' do
        it 'updates the given resource' do
          expect(client).to receive(:patch).with(url, body: params)
          subject.update(1, params)
        end
      end

      describe '#destroy' do
        it 'destroys the given resource' do
          expect(client).to receive(:delete).with(url)
          subject.destroy(1)
        end
      end
    end
  end
end
