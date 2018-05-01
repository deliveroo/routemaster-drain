require 'spec_helper'
require 'routemaster/errors'

describe Routemaster::Errors::FatalResource do
  let(:body) { "{ \"foo\": \"bar\" }" }
  let(:env) { double(body: body, url: '/foo/bar', method: 'GET') }
  subject(:error) { described_class.new(env) }

  describe "#message" do
    subject { error.message }
    it { is_expected.to eq "Fatal Resource Error. body: { \"foo\": \"bar\" }, url: /foo/bar, method: GET" }

    context 'even if the body is string' do
      let(:body) { "foobar" }
      it { is_expected.to eq "Fatal Resource Error. body: foobar, url: /foo/bar, method: GET" }
    end
  end
end
