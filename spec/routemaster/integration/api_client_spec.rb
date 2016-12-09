require 'spec_helper'
require 'spec/support/uses_redis'
require 'spec/support/uses_dotenv'
require 'routemaster/api_client'
require 'webrick'

RSpec.describe 'Api client integration specs' do
  uses_dotenv
  uses_redis

  let!(:log) { WEBrick::Log.new '/dev/null' }
  let(:service) do
    WEBrick::HTTPServer.new(Port: 8000, DocumentRoot: Dir.pwd, Logger: log).tap do |server|
      [400, 401, 403, 404, 409, 412, 413, 429, 500].each do |status_code|
        server.mount_proc "/#{status_code}" do |req, res|
          res.status = status_code
          res.body = { field: 'test' }.to_json
        end
      end
    end
  end

  before do
    @pid = fork do
      trap 'INT' do service.shutdown end
      service.start
    end
    sleep(0.5) # leave sometime for the previous webrick to teardown
  end

  after do
    Process.kill('KILL', @pid)
    Process.wait(@pid)
  end

  subject { Routemaster::APIClient.new }
  let(:host) { 'http://localhost:8000' }

  describe 'error handling' do
    it 'raises an ResourceNotFoundError on 404' do
      expect { subject.get(host + '/404') }.to raise_error(Routemaster::Errors::ResourceNotFoundError)
    end

    it 'raises an InvalidResourceError on 400' do
      expect { subject.get(host + '/400') }.to raise_error(Routemaster::Errors::InvalidResourceError)
    end

    it 'raises an UnauthorizedResourceAccessError on 401' do
      expect { subject.get(host + '/401') }.to raise_error(Routemaster::Errors::UnauthorizedResourceAccessError)
    end

    it 'raises an UnauthorizedResourceAccessError on 403' do
      expect { subject.get(host + '/403') }.to raise_error(Routemaster::Errors::UnauthorizedResourceAccessError)
    end

    it 'raises an ConflictResourceError on 409' do
      expect { subject.get(host + '/409') }.to raise_error(Routemaster::Errors::ConflictResourceError)
    end

    it 'raises an IncompatibleVersionError on 412' do
      expect { subject.get(host + '/412') }.to raise_error(Routemaster::Errors::IncompatibleVersionError)
    end

    it 'raises an InvalidResourceError on 413' do
      expect { subject.get(host + '/413') }.to raise_error(Routemaster::Errors::InvalidResourceError)
    end

    it 'raises an ResourceThrottlingError on 429' do
      expect { subject.get(host + '/429') }.to raise_error(Routemaster::Errors::ResourceThrottlingError)
    end

    it 'raises an FatalResourceError on 500' do
      expect { subject.get(host + '/500') }.to raise_error(Routemaster::Errors::FatalResourceError)
    end
  end
end
