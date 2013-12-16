require 'net/dhcp'
require 'log4r'

module DHCPD
  class Packet
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

    def initialize(type, pool, msg)
      @type = type
      @reply = ACTION_MAP[@type]
      @pool = pool
      @msg = msg
      @hwaddr = Helper.to_hwaddr(msg.chaddr,msg.hlen)
      @log = Log4r::Logger['ruby-dhcpd']
    end

    def send(socket)
      @socket = socket
      send_packet(create_packet) if @reply
    end

    private

    def create_packet
      lock = (@reply == :ack ? true : false)
      payload = @pool.get_payload(@hwaddr,lock)
      params = {
	op: $DHCP_OP_REPLY,
	xid: @msg.xid,
	chaddr: @msg.chaddr,
	yiaddr: payload[:ipaddr],
	siaddr: IPAddr.new(payload[:dhcp_server].join('.')).to_i,
	fname: payload[:filename],
	options: [
	  REPLY_TYPES[@reply],
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

    def send_packet(packet)
      @log.info "Send DHCP #{@reply.to_s.upcase} message to #{@hwaddr}."
      @socket.send(packet, 0, '255.255.255.255', CLIENT_DHCP_PORT)
    end
  end
end
