require 'spec_helper'
require 'timeout'

# Patch WEBrick as it doesn't support PATCH (?)
module WEBrick
  module HTTPServlet
    class ProcHandler
      alias do_PATCH do_GET
      alias do_DELETE do_GET
    end
  end
end

class TestServer
  def initialize(port, &block)
    @port = port
    @setup = block
  end

  def start
    return if @pid
    @pid = fork do
      WEBrick::HTTPServer.new(
        Port: @port,
        DocumentRoot: Dir.pwd,
        Logger: WEBrick::Log.new('/dev/null'),
        AccessLog: [nil, nil]
      ).tap do |server|
        @setup.call(server)
        server.start
      end
    end

    # wait until the child server is up
    Timeout.timeout(5) do
      loop do
        begin
          TCPSocket.new('127.0.0.1', @port)
        rescue Errno::ECONNREFUSED
          sleep 0.1
          next
        end
        break
      end
    end
  end

  def stop
    return unless @pid
    Process.kill('KILL', @pid)
    Process.wait(@pid)
  end
end
