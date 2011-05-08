require 'cnu'

# Helpers for parsing and prettifying strings etc

module CNU::Parsers
  protected
  def get_pgerror(error)
    # ##### example raw postgres errors: ###
    # ActiveRecord::StatementInvalid: PGError: ERROR:  [[[Duplicate IP ADDRESS: 192.168.1.213/26 not allowed]]] : COMMIT
    # PGError: ERROR:  duplicate key value violates unique constraint "local_port_unique"
    # : INSERT INTO "services" ("name", "local_port", "url", "service_port", "check_port", "availability", "check_url", "glb_availablilty", "protocol_id", "description", "not_unique", "ip_address", "trending_url") VALUES('something', 5461, 'http://something.com', 80, NULL, 'campus', NULL, NULL, 1, 'bal dawla dwa ', 1, '10.10.10.177', NULL)

    error.message.split('PGError: ERROR:')[1].split(/\s:\s/)[0].strip
  end
end

