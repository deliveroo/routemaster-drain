require 'spec_helper'
require 'routemaster/responses/hateoas_response'

module Routemaster
  module Responses
    RSpec.describe HateoasResponse do
      let(:response) { double('Response', status: status, body: body, headers: headers) }
      let(:status) { 200 }
      let(:body) { {}.to_json }
      let(:headers) { {} }

      subject { described_class.new(response) }

      context 'link traversal' do
        let(:body) do
          {
            '_links' => {
              'self' => { 'href' => 'self_url' },
              'resource_a' => { 'href' => 'resource_a_url' },
              'resource_b' => { 'href' => 'resource_b_url' }
            }
          }
        end

        it 'creates a method for every key in _links attribute' do
          expect(subject.resource_a.url).to eq('resource_a_url')
          expect(subject.resource_b.url).to eq('resource_b_url')
        end

        it 'creates a _self method if there is a link with name self' do
          expect(subject._self.url).to eq('self_url')
        end

        it 'raise an exception when requested link does not exist' do
          expect { subject.some_unsupported_link }.to raise_error(NoMethodError)
        end

        describe '#body_without_links' do
          before do
            body.merge!('foo' => 'bar')
          end

          it 'returns the body without the _links key' do
            expect(subject.body_without_links).to eq({ 'foo' => 'bar' })
          end
        end
      end
    end
  end
end
