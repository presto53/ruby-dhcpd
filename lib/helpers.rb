module DHCPD
  class Helper
    # Converts array to string representation of MAC address
    #
    # @param chaddr [Array] the array of integers
    # @param hlen [Fixnum] the count of numbers we should take from array
    # @return [String] the object converted to the expected format.
    def self.to_hwaddr(chaddr,hlen)
      chaddr.take(hlen).map {|x| x.to_s(16).size<2 ? '0'+x.to_s(16) : x.to_s(16)}.join(':')
    end
  end
end
