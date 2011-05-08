module CNU::Isimud

  class SSH

    attr_accessor :host, :user, :conn_info

    public
      def initialize(host, user, conn_info)
        @host = host
        @user = user
        @conn_info = conn_info
      end

      def exec(command, throw_on_error=false)
        results = execute_command(command)
        if throw_on_error and results.has_key[:ext_data]
          raise Exception.new(output[:ext_data])
        else
          return results
        end
      end

    protected
      def execute_command(command)
        (output = {})[:command] = command
        if ENV['RAILS_ENV'] == 'production'
          Net::SSH.start(@host, @user, @conn_info) do |session|
            session.open_channel do |channel|
              channel.exec("expr [#{command}]") do |ch, success|
                abort unless success
                channel.on_data do |ch, data|
                  (output[:data] ||= []) << data
                end
                channel.on_extended_data do |ch, type, data|
                  next unless type == 1
                  output[:ext_type] = type
                  output[:ext_data] = data
                end
                channel.on_request("exit-status") do |ch, data|
                  output[:exit_code] = data.read_long
                end
              end
            end
          end
        end
        output
    end
  end

end
