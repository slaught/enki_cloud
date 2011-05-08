module CNU::Gozer::SanTypes

  # Interface to executing commands on a Equallogic SAN
  class EqualLogic

    attr_accessor :conn_info, :logger

    public
      def initialize
        # TODO - Determine the actual location for the final key
      end
  end

end
