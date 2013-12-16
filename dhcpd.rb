#!/usr/bin/env ruby
require 'bundler'
Bundler.setup
require_relative 'lib/dhcpd'
require_relative 'config.rb'

module DHCPD
  class Config
    SERVER_DHCP_PORT = 67
    CLIENT_DHCP_PORT = 68
  end
end

DHCPD::Server.new((ARGV[0] || DHCPD::Config::SERVER_BIND_IP)).run
