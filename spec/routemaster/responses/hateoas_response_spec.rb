require 'spec_helper'
require 'routemaster/responses/hateoas_response'

module Routemaster
  module Responses
    RSpec.describe HateoasResponse do
      let(:response) { double('Response', status: status, body: body, headers: headers) }
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
              ]
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

        context 'with a paginated response' do
          let(:body) do
            {
              'page' => 1,
              'per_page' => 2,
              'total' => 3,
              '_links' => {
                'self' => { 'href' => 'self_url' },
                'prev' => nil,
                'next' => 'page_2_url',
                'chocolates' => [
                  { 'href' => 'chocolate_1_url' },
                  { 'href' => 'chocolate_2_url' }
                ]
              }
            }
          end

          let(:body2) do
            {
              'page' => 2,
              'per_page' => 2,
              'total' => 3,
              '_links' => {
                'self' => { 'href' => 'self_url' },
                'prev' => 'page_1_url',
                'next' => nil,
                'chocolates' => [
                  { 'href' => 'chocolate_3_url' }
                ]
              }
            }
          end

          let(:response2) { double('Response', status: status, body: body2, headers: headers) }

          before do
            allow(client).to receive(:get).with('page_2_url') { described_class.new(response2, client: client)}
          end

          it 'returns an enumerator with all the chocolates' do
            chocolate_urls = ['chocolate_1_url', 'chocolate_2_url', 'chocolate_3_url']
            expect(subject.chocolates).to be_a(Enumerator)
            expect(subject.chocolates).to all(be_a(Resources::RestResource))
            expect(subject.chocolates.map(&:url)).to eq chocolate_urls
          end
        end
      end
    end
  end
end
