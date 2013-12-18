require 'socket'
require 'net-dhcp'
require 'log4r'
require_relative 'helpers'
require_relative 'pool'
require_relative 'packet'

module DHCPD
  class Server
    include DHCP

    def initialize(bind_ip)
      set_logger
      @bind_ip = bind_ip
      @ip_pool = Pool.new(Config::POOL_MODE)
    end

    # Server runner
    # First it's bind to socket and then receive and process messages
    def run
      bind
      loop do
	@log.error 'Unknown error while processing received message.' unless process(receive)
      end
    end

    private

    # Logger configuration
    def set_logger
      @log = Log4r::Logger.new 'ruby-dhcpd'
      @log.outputters << Log4r::Outputter.stdout
      format = Log4r::PatternFormatter.new(:pattern => "[%l] [%d] %m")
      @log.outputters << Log4r::FileOutputter.new('dhcpd.log', filename:  Config::LOG_FILE, formatter: format)
      @log.level = Config::LOG_LEVEL
    end

    # Create UDP socket and bind to it.
    #
    # if bind failed exit with status code 1
    # @return [true] result of binding
    def bind
      @socket = UDPSocket.new
      @socket.setsockopt( Socket::SOL_SOCKET, Socket::SO_BROADCAST, true )
      if @socket.bind(@bind_ip,Config::SERVER_DHCP_PORT)
	@log.info "Bind to #{@bind_ip} successful."
      else
	@log.fatal "Bind to #{@bind_ip} failed."
	exit 1
      end
    end

    # Receive message from socket
    #
    # @return [Hash] received message and address of sender
    # @option received [Message] :msg Net::DHCP::Message object
    # @option received [Array] :addr is an array to represent the sender address
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

    # Process received data
    #
    # @param [Hash] data received from socket
    # @option data [Message] :msg Net::DHCP::Message object
    # @option data [Array] :addr is an array to represent the sender address
    def process(data)
      msg = data[:msg]
      addr = data[:addr]
      hwaddr = Helper.to_hwaddr(msg.chaddr,msg.hlen)
      @log.debug "Message from #{hwaddr}. Yay!"
      msg_type = Packet::REQUEST_TYPES.clone
      msg_type.keep_if {|type, body| msg.options.include?(body)}
      return false if msg_type.size != 1
      received_type = msg_type.shift[0]
      @log.info "DHCP #{received_type.to_s.upcase} message from #{hwaddr}."
      reply = Packet.new(received_type, @ip_pool,msg)
      begin
	reply.send(@socket)
      rescue
	@log.error 'Error while creating reply packet.'
      end
    end
  end
end
