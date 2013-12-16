module DHCPD
  class Helper
    def self.to_hwaddr(chaddr,hlen)
      chaddr.take(hlen).map {|x| x.to_s(16).size<2 ? '0'+x.to_s(16) : x.to_s(16)}.join(':')
    end
  end
end
