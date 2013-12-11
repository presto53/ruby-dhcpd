require 'socket'
require 'ipaddr'
require 'net-dhcp'
require 'log4r'
require_relative 'helpers'

module DHCPD
  class DHCPD
    include DHCP

    def initialize(ip_pool)
      @ip_pool = pool_from(ip_pool)
      @log = Log4r::Logger.new 'ruby-dhcpd'
      @log.outputters = Log4r::Outputter.stdout
      @log.level = LOG_LEVEL
      @request_types = {
          discover: MessageTypeOption.new({payload: [$DHCP_MSG_DISCOVER]}),
          request: MessageTypeOption.new({payload: [$DHCP_MSG_REQUEST]}),
          decline: MessageTypeOption.new({payload: [$DHCP_MSG_DECLINE]}),
          release: MessageTypeOption.new({payload: [$DHCP_MSG_RELEASE]}),
          inform: MessageTypeOption.new({payload: [$DHCP_MSG_INFORM]})
      }
      @reply_types = {
          offer: MessageTypeOption.new({payload: [$DHCP_MSG_OFFER]}),
          ack: MessageTypeOption.new({payload: [$DHCP_MSG_ACK]}),
          nack: MessageTypeOption.new({payload: [$DHCP_MSG_NACK]})
      }

    end

    def run
      bind
      loop do
        req = receive
        process(req[:msg],req[:addr])
      end
    end

    private

    def bind
      @socket = UDPSocket.new
      #@socket.setsockopt( Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true )
      @socket.setsockopt( Socket::SOL_SOCKET, Socket::SO_BROADCAST, true )
      if @socket.bind(SERVER_BIND_IP,SERVER_DHCP_PORT)
        @log.info "Binding to #{SERVER_BIND_IP} successful."
      else
        @log.fatal "Can not bind to #{SERVER_BIND_IP}."
        exit 1
      end
    end

    def receive
      begin
        data, addr = @socket.recvfrom_nonblock(1500)  #=> ["aaa", ["AF_INET", 33302, "localhost.localdomain", "127.0.0.1"]]
        msg = Message.from_udp_payload(data)
      rescue IO::WaitReadable
        IO.select([@socket])
        retry
      end
      {msg: msg, addr: addr}
    end

    def process(msg,addr)
      hwaddr = to_hwaddr(msg.chaddr,msg.hlen)
      @log.debug "DHCP message from #{hwaddr}. Yay!"
      requested = false
      msg.options.each do |op|
        requested = op if @request_types.values.include?(op)
      end
      @log.info "DHCP request: #{requested}"

      case requested
        when @request_types[:discover] then
          @log.info "DHCP DISCOVER message from #{hwaddr}."
          offer(msg,addr)
        when @request_types[:request] then
          @log.info "DHCP REQUEST message from #{hwaddr}."
          ack(msg, addr)
        when @request_types[:decline] then
          @log.info "DHCP DECLINE message from #{hwaddr}."
        when @request_types[:release] then
          @log.info "DHCP RELEASE message from #{hwaddr}."
          release(msg, addr)
        when @request_types[:inform] then
          @log.info "DHCP INFORM message from #{hwaddr}."
          inform(msg, addr)
        else
          @log.warn "We received something strange.... EXTERMINA-A-A-ATE!"
      end
    end

    def offer(msg, addr)
      @log.info "Send DHCP OFFER message to #{to_hwaddr(msg.chaddr,msg.hlen)}."
      send_packet(msg, addr, :offer)
    end

    def ack(msg, addr)
      @log.info "Send DHCP ACK message to #{to_hwaddr(msg.chaddr,msg.hlen)}."
      send_packet(msg, addr, :ack)
    end

    def release(msg, addr)
      @log.info "RELEASE will be when release will be."
    end

    def inform(msg, addr)
      @log.info "INFORM not yet implemented. Soon..."
    end

    def send_packet(msg,addr,type)
      packet = craft_packet(msg,addr,type)
      @socket.send(packet, 0, '255.255.255.255', CLIENT_DHCP_PORT)
    end

    def craft_packet(msg,addr,type)
      hwaddr = to_hwaddr(msg.chaddr,msg.hlen)
      payload = remote_get_payload(hwaddr, type)
      unless payload
	payload = Hash.new
	@ip_pool[:options].each {|op, data| payload[op] = data} 
	payload[:ipaddr] = ip_from_default_pool(hwaddr).to_i
      end
      params = {
          op: $DHCP_OP_REPLY,
          xid: msg.xid,
          chaddr: msg.chaddr,
          yiaddr: payload[:ipaddr],
          siaddr: IPAddr.new(payload[:dhcp_server].join('.')).to_i,
	  fname: payload[:filename],
          options: [
              @reply_types[type],
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
  end
end
