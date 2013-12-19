require 'net/dhcp'
require 'ipaddr'
require 'log4r'
require_relative 'helpers'

module DHCPD
  class Packet
    include DHCP

    REQUEST_TYPES = {
      discover: MessageTypeOption.new({payload: [$DHCP_MSG_DISCOVER]}),
      request: MessageTypeOption.new({payload: [$DHCP_MSG_REQUEST]}),
      decline: MessageTypeOption.new({payload: [$DHCP_MSG_DECLINE]}),
      release: MessageTypeOption.new({payload: [$DHCP_MSG_RELEASE]}),
      inform: MessageTypeOption.new({payload: [$DHCP_MSG_INFORM]})
    }
    REPLY_TYPES = {
      offer: MessageTypeOption.new({payload: [$DHCP_MSG_OFFER]}),
      ack: MessageTypeOption.new({payload: [$DHCP_MSG_ACK]}),
      nack: MessageTypeOption.new({payload: [$DHCP_MSG_NACK]})
    }
    ACTION_MAP = {
      :discover => :offer,
      :request => :ack,
      :decline => false,
      :release => false,
      :inform => false
    }

    def initialize(received_type, pool, msg)
      @received_type = received_type
      @type = Packet::ACTION_MAP[received_type]
      @pool = pool
      @msg = msg
      @hwaddr = Helper.to_hwaddr(msg.chaddr,msg.hlen)
      @log = Log4r::Logger['ruby-dhcpd']
    end

    # Send object to socket
    #
    # @param socket [UDPSocket] the UDP socket object
    # @return [true,false] result of operation 
    def send(socket)
      @socket = socket
      if @type
	data = create_packet
	send_packet(data) unless data == :netboot
      else
	@log.info "Reply for #{@received_type.to_s.upcase} not implemented yet."
	true
      end
    end

    private

    # Construct reply packet from received message and from pool settings
    #
    # @return [String] packed Net::DHCP::Message object
    def create_packet
      lock = (@type == :ack ? true : false)
      payload = @pool.get_payload(@hwaddr,lock)
      return :noboot if payload[:netboot] == 'false'
      params = {
	op: $DHCP_OP_REPLY,
	xid: @msg.xid,
	chaddr: @msg.chaddr,
	yiaddr: payload[:ipaddr],
	siaddr: IPAddr.new(payload[:dhcp_server].join('.')).to_i,
	fname: payload[:filename],
	options: [
	  REPLY_TYPES[@type],
	  ServerIdentifierOption.new({payload: payload[:dhcp_server]}),
	  DomainNameOption.new({payload: payload[:domainname]}),
	  DomainNameServerOption.new({payload: payload[:dns_server]}),
	  IPAddressLeaseTimeOption.new({payload: payload[:lease_time]}),
	  SubnetMaskOption.new({payload: payload[:subnet_mask]}),
	  RouterOption.new({payload: payload[:gateway]})
	]
      }
      Message.new(params).pack
    end

    # Send packet to socket
    #
    # @param packet [String] packed Net::DHCP::Message object
    # @return [true,false] result of operation
    def send_packet(packet)
      @log.info "Send DHCP #{@type.to_s.upcase} message to #{@hwaddr}."
      @socket.send(packet, 0, IPAddr.new(Config::SERVER_SUBNET).to_range.to_a.pop.to_s, Config::CLIENT_DHCP_PORT)
    end
  end
end
