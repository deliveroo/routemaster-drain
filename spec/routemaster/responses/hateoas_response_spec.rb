require 'spec_helper'
require 'routemaster/responses/hateoas_response'

module Routemaster
  module Responses
    RSpec.describe HateoasResponse do
      let(:response) { double('Response', status: status, body: body, headers: headers, env: double) }
      let(:status) { 200 }
      let(:body) { {}.to_json }
      let(:headers) { {} }
      let(:client) { double }

      subject { described_class.new(response, client: client) }

      context 'link traversal' do
        let(:body) do
          {
            '_links' => {
              'self' => { 'href' => 'self_url' },
              'resource_a' => { 'href' => 'resource_a_url' },
              'resource_b' => { 'href' => 'resource_b_url' },
              'resource_cs' => [
                { 'href' => 'resource_c_1_url' },
                { 'href' => 'resource_c_2_url' }
              ],
              'chocolates' => { 'href' => 'http://example.com/chocolates' }
            }
          }
        end

        describe 'singular resources' do
          it 'creates a method for each singular resource in _links attribute, exposing a rest resource' do
            expect(subject.resource_a.url).to eq('resource_a_url')
            expect(subject.resource_a).to be_a(Resources::RestResource)
            expect(subject.resource_b.url).to eq('resource_b_url')
            expect(subject.resource_b).to be_a(Resources::RestResource)
          end
        end

        describe 'collection resources' do
          it 'creates a list for keys with a list resource' do
            expect(subject.resource_cs.first.url).to eq('resource_c_1_url')
            expect(subject.resource_cs.first).to be_a(Resources::RestResource)
            expect(subject.resource_cs.last.url).to eq('resource_c_2_url')
            expect(subject.resource_cs.last).to be_a(Resources::RestResource)
          end
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

        describe '#has?' do
          it 'returns true for an existing link' do
            expect(subject.has?(:resource_a)).to be_truthy
          end

          it 'returns false for a non existing link' do
            expect(subject.has?(:other_resource)).to be_falsy
          end
        end

        context 'collections' do
          let(:chocolate_1_body) do
            {
              'name' => 'Lindor',
              '_links' => {
                'self' => { 'href' => 'http://example.com/chocolates/1' },
              }
            }
          end

          let(:chocolate_2_body) do
            {
              'name' => 'Cadburys',
              '_links' => {
                'self' => { 'href' => 'http://example.com/chocolates/2' },
              }
            }
          end

          let(:chocolate_3_body) do
            {
              'name' => 'Dairy Milk',
              '_links' => {
                'self' => { 'href' => 'http://example.com/chocolates/2' },
              }
            }
          end

          before do
            stub_url_with_body('http://example.com/chocolates/1', chocolate_1_body, fget: true)
            stub_url_with_body('http://example.com/chocolates/2', chocolate_2_body, fget: true)
            stub_url_with_body('http://example.com/chocolates/3', chocolate_3_body, fget: true)
          end

          context 'with a non-paginated response' do
            let(:chocolates_body) do
              {
                '_links' => {
                  'self' => { 'href' => 'self_url' },
                  'chocolates' => [
                    { 'href' => 'http://example.com/chocolates/1' },
                    { 'href' => 'http://example.com/chocolates/2' },
                    { 'href' => 'http://example.com/chocolates/3' }
                   ]
                }
              }
            end

            before do
              stub_url_with_body('http://example.com/chocolates', chocolates_body)
            end

            specify 'using the index action returns an enuerable response with all chocolates on the page' do
              expect(subject.chocolates.index).to be_a(EnumerableHateoasResponse)
              expect(subject.chocolates.index).to all(be_a(Resources::RestResource))
              expect(subject.chocolates.index.map(&:url))
                .to eq ['http://example.com/chocolates/1', 'http://example.com/chocolates/2', 'http://example.com/chocolates/3']
            end

            specify 'the chocolates can also be accesses directly as an attribute of the response' do
              expect(subject.chocolates.index.chocolates).to be_a(Enumerable)
              expect(subject.chocolates.index.chocolates).to all(be_a(Resources::RestResource))
              expect(subject.chocolates.index.chocolates.map(&:url))
                .to eq ['http://example.com/chocolates/1', 'http://example.com/chocolates/2', 'http://example.com/chocolates/3']
            end

            specify 'using the future index action returns an enuerable response with all chocolates on the page' do
              expect(subject.chocolates.future_index).to all(be_a(HateoasResponse))
              expect(subject.chocolates.future_index.map(&:name)).to eq(["Lindor", "Cadburys", "Dairy Milk"])
            end
          end

          context 'with a paginated response' do
            let(:chocolates_page_1_body) do
              {
                'page' => 1,
                'per_page' => 2,
                'total' => 3,
                '_links' => {
                  'self' => { 'href' => 'self_url' },
                  'prev' => nil,
                  'next' => 'http://example.com/chocolates?page=2',
                  'chocolates' => [
                    { 'href' => 'http://example.com/chocolates/1' },
                    { 'href' => 'http://example.com/chocolates/2' }
                   ]
                }
              }
            end

            let(:chocolates_page_2_body) do
              {
                'page' => 2,
                'per_page' => 2,
                'total' => 3,
                '_links' => {
                  'self' => { 'href' => 'self_url' },
                  'prev' => 'http://example.com/chocolates',
                  'next' => nil,
                  'chocolates' => [
                    { 'href' => 'http://example.com/chocolates/3' }
                  ]
                }
              }
            end

            before do
              stub_url_with_body('http://example.com/chocolates', chocolates_page_1_body)
              stub_url_with_body('http://example.com/chocolates?page=2', chocolates_page_2_body)
            end

            specify 'using the index action returns an enumerable response with all the chocolates from every page' do
              expect(subject.chocolates.index).to be_a(EnumerableHateoasResponse)
              expect(subject.chocolates.index).to all(be_a(Resources::RestResource))
              expect(subject.chocolates.index.map(&:url))
                .to eq ['http://example.com/chocolates/1', 'http://example.com/chocolates/2', 'http://example.com/chocolates/3']
            end

            specify 'using the future index action returns an enuerable response with all chocolates on the page' do
              expect(subject.chocolates.future_index).to all(be_a(HateoasResponse))
              expect(subject.chocolates.future_index.map(&:name)).to eq(["Lindor", "Cadburys", "Dairy Milk"])
            end
          end
        end
      end
    end
  end
end

def stub_url_with_body(url, body, fget: false)
  method = fget ? :fget : :get

  faraday_env = double('Env', url: URI.parse(url))
  faraday_response = double('Response', status: 200, body: body, headers: {}, env: faraday_env)
  response = described_class.new(faraday_response, client: client)
  allow(client).to receive(method).with(url) { response }
end
