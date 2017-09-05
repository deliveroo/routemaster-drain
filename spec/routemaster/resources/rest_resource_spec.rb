require 'spec_helper'
require 'routemaster/resources/rest_resource'

module Routemaster
  module Resources
    RSpec.describe RestResource do
      let(:client) { double('Client') }
      let(:params) { {} }

      describe "singular resource" do
        let(:url) { '/resources/1' }

        subject { described_class.new('/resources/{id}', client: client) }

        describe '#show' do
          it 'gets to the given url' do
            expect(client).to receive(:get).with(url, options: { enable_caching: true })
            subject.show(1)
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

      describe "collection resource" do
        let(:url) { '/resources' }

        subject { described_class.new('/resources{?page,per_page}', client: client) }

        describe '#create' do
          it 'posts to the given url' do
            expect(client).to receive(:post).with(url, body: params)
            subject.create(params)
          end
        end

        describe '#index' do
          it 'gets to the given url' do
            expect(client).to receive(:get).with(
              url, params: {}, options: {
                enable_caching: false, response_class: Routemaster::Responses::HateoasEnumerableResponse
              }
            )
            subject.index
          end
        end
      end
    end
  end
end
