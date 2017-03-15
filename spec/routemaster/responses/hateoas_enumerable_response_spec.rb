require 'spec_helper'
require 'spec/support/uses_webmock'
require 'spec/support/uses_redis'
require 'routemaster/responses/hateoas_enumerable_response'

# need to load this here to resolve circular dependency
require 'routemaster/resources/rest_resource'

describe Routemaster::Responses::HateoasEnumerableResponse do
  uses_webmock
  uses_redis

  let(:resource_tpl) { Addressable::Template.new('https://example.com/shebangs/{id}') }
  let(:index_tpl) { Addressable::Template.new('https://example.com/shebangs{?page,per_page}') }
  let(:index_url) { index_tpl.expand(page: nil, per_page:nil).to_s }
  let(:pages) { 5 }
  let(:per_page) { 3 }

  before do
    @resource_stub = stub_request(:get, resource_tpl).to_return do |req|
      {
        status: 200,
        headers: { 'Content-Type' => 'application/json' },
        body: {
          id: req.uri.path.split('/').last.to_i,
          _links: {
            self: { href: req.uri.to_s },
          }
        }.to_json
      }
    end

    @index_stub = stub_request(:get, index_tpl).to_return do |req|
      req.uri.query_values ||= { 'page' => '1' }
      page = req.uri.query_values['page'].to_i
      start = (page-1) * per_page + 1
      stop  = page * per_page

      data = Hashie::Mash.new(
        _links: {
          self: { href: index_tpl.expand(page: page, per_page: per_page).to_s },
          shebangs: (start..stop).map { |idx|
            { href: resource_tpl.expand(id: idx).to_s }
          }
        },
        page: page,
        per_page: per_page,
        total: pages * per_page,
      )

      data._links.next!.href = index_tpl.expand(page: page+1, per_page: per_page).to_s if page < pages
      data._links.prev!.href = index_tpl.expand(page: page-1, per_page: per_page).to_s if page > 1

      { status: 200, headers: { 'Content-Type' => 'application/json' },  body: data.to_json }
    end
  end

  let(:client) { Routemaster::APIClient.new }
  subject { described_class.new(client.get(index_url)) }

  # so we don't pollute future specs with pending requests:
  after { Routemaster::Responses::ResponsePromise::Pool.reset }

  describe '#each' do
    it 'is enumerable' do
      expect(subject.count).to eq(15)
    end

    it 'lists all paginated resources' do
      expect(subject.map(&:body).map(&:id)).to eq (1..15).to_a
    end

    it 'does not fetch eagerly' do
      subject.first
      expect(@index_stub).to have_been_requested.once
    end
  end
end
