require 'socket'
require 'ipaddr'
require 'net-dhcp'
require 'log4r'
require_relative 'helpers'

module DHCPD
  class Server
    include DHCP
    include DHCPD

    def initialize
      set_logger
      @ip_pool = Pool.new(Config::POOL_MODE)
    end

    def run
      bind
      loop do
	@log.error 'Unknown error while processing received message.' unless process(receive)
      end
    end

    private

    def self.set_logger
      @log = Log4r::Logger.new 'ruby-dhcpd'
      @log.outputters << Log4r::Outputter.stdout
      @log.outputters << Log4r::FileOutputter.new('dhcpd.log', filename:  Config::LOG_FILE)
      @log.level = Config::LOG_LEVEL
    end

    def bind
      @socket = UDPSocket.new
      @socket.setsockopt( Socket::SOL_SOCKET, Socket::SO_BROADCAST, true )
      if @socket.bind(Config::SERVER_BIND_IP,Config::SERVER_DHCP_PORT)
	@log.info "Bind to #{Config::SERVER_BIND_IP} successful."
      else
	@log.fatal "Bind to #{Config::SERVER_BIND_IP} failed."
	exit 1
      end
    end

    def receive
      begin
	data, addr = @socket.recvfrom_nonblock(1500)
	msg = Message.from_udp_payload(data)
      rescue IO::WaitReadable
	IO.select([@socket])
	retry
      end
      {msg: msg, addr: addr}
    end

    def process(data)
      msg = data[:msg]
      addr = data[:addr]
      hwaddr = Helper.to_hwaddr(msg.chaddr,msg.hlen)
      @log.debug "Message from #{hwaddr}. Yay!"
      msg_type = Packet::REQUEST_TYPES
      msg_type.keep_if {|type, body| msg.options.include?(body)}
      return false if msg_type.size != 1
      msg.options.each do |option|
	type = Packet::REQUEST_TYPES.rassoc(option) if Packet::REQUEST_TYPES.values.include?(option)
      end
      @log.info "DHCP #{type.to_s.upcase} message from #{hwaddr}."
      reply = Packet.new(type, @ip_pool,msg)
      begin
	reply.send(@socket)
      rescue
	@log.error 'Error while creating reply packet.'
      end
    end
  end
end
