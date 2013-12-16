#!/usr/bin/env ruby
require 'bundler'
Bundler.setup
require_relative 'lib/dhcpd'

module DHCPD
  class Config
    load 'config.rb'
    SERVER_DHCP_PORT = 67
    CLIENT_DHCP_PORT = 68
  end
end

DHCPD::Server.new.run
