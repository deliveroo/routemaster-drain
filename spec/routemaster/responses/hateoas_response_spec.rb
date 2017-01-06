require 'spec_helper'
require 'routemaster/responses/hateoas_response'

module Routemaster
  module Responses
    RSpec.describe HateoasResponse do
      let(:env) { double('Env', url: URI.parse('http://example.com/washing_machines')) }
      let(:response) { double('Response', status: status, body: body, headers: headers, env: env) }
      let(:status) { 200 }
      let(:body) { {}.to_json }
      let(:headers) { {} }
      let(:client) { double }

      subject { described_class.build(response, client: client) }

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
          let(:chocolate_urls) { ['http://example.com/chocolates/1', 'http://example.com/chocolates/2', 'http://example.com/chocolates/3'] }

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

            let(:chocolates_env) { double('Env', url: URI.parse('http://example.com/chocolates')) }
            let(:chocolates_response) { double('Response', status: status, body: chocolates_body, headers: headers, env: chocolates_env) }

            before do
              allow(client).to receive(:get).with('http://example.com/chocolates') { described_class.build(chocolates_response, client: client)}
            end

            specify 'using the index action returns an enuerable response with all chocolates on the page' do
              expect(subject.chocolates.index).to be_a(HateoasResponse)
              expect(subject.chocolates.index).to all(be_a(Resources::RestResource))
              expect(subject.chocolates.index.map(&:url)).to eq chocolate_urls
            end

            specify 'the chocolates can also be accesses directly as an attribute of the response' do
              expect(subject.chocolates.index.chocolates).to be_a(Enumerable)
              expect(subject.chocolates.index.chocolates).to all(be_a(Resources::RestResource))
              expect(subject.chocolates.index.chocolates.map(&:url)).to eq chocolate_urls
            end
          end

          context 'with a paginated response' do
            let(:chocolates_body_1) do
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

            let(:chocolates_body_2) do
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

            let(:chocolates_env_1) { double('Env', url: URI.parse('http://example.com/chocolates')) }
            let(:chocolates_response_1) { double('Response', status: status, body: chocolates_body_1, headers: headers, env: chocolates_env_1) }
            let(:chocolates_env_2) { double('Env', url: URI.parse('http://example.com/chocolates?page=2')) }
            let(:chocolates_response_2) { double('Response', status: status, body: chocolates_body_2, headers: headers, env: chocolates_env_2) }


            before do
              allow(client).to receive(:get).with('http://example.com/chocolates') { described_class.build(chocolates_response_1, client: client)}
              allow(client).to receive(:get).with('http://example.com/chocolates?page=2') { described_class.build(chocolates_response_2, client: client)}
            end

            specify 'using the index action returns an enumerable response with all the chocolates from every page' do
              expect(subject.chocolates.index).to be_a(HateoasResponse)
              expect(subject.chocolates.index).to all(be_a(Resources::RestResource))
              expect(subject.chocolates.index.map(&:url)).to eq chocolate_urls
            end

            specify 'the chocolates can also be accessed directly as an attribute of the response' do
              expect(subject.chocolates.index.chocolates).to be_a(Enumerable)
              expect(subject.chocolates.index.chocolates).to all(be_a(Resources::RestResource))
              expect(subject.chocolates.index.chocolates.map(&:url)).to eq chocolate_urls
            end
          end
        end
      end
    end
  end
end
