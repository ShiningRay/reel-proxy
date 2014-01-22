require 'rubygems'
require 'bundler/setup'
require 'celluloid/autostart'


class TestPub
  include Celluloid
  include Celluloid::Notifications
  def initialize
    async.run
  end
  def run
    now = Time.now.to_f
    sleep now.ceil - now + 0.001
    every(1) do
      publish 'read_message', now
    end
  end
end

class TestSub
  include Celluloid
  include Celluloid::Notifications
  include Celluloid::Logger

  def initialize
    info "Writing to socket"
    subscribe('read_message', :read_message)
  end

  def read_message(*args)
    info args
  end
end

TestPub.supervise_as :test_pub
TestSub.supervise_as :test_sub

sleep