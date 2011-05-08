module CNU::Gozer::SanTypes

  # Interface to executing commands on a 3par SAN
  class ThreePar

    SanitizerHash = {
      :ip => %r{[^-\d\.]+},
      :hostname =>%r{[^-\w\.]+},
    }

    # Bad argument passed to #validate_arg
    class BadArgument < Exception; end
    # Bad argument passed to #run
    class BadAction < Exception; end
    # This is thwon when we get the wrong action type in ThreePar#vlun_mgmt
    class BadSnapshotType < Exception; end
    # You didn't provide one of the required arguments
    class MissingArgument < Exception; end


    public
      def initialize
        # Populate variables with useful values
        #@ssh = CNU::Isimud::SSH.new('localhost','cnuit_auto',
                         #{ :port => 2222, :keys => ['/etc/cnu/keys/cnuit_auto.key'] })
        @ssh = CNU::Isimud::SSH.new(ThreeParConfig['host'],
                                     ThreeParConfig['user'],
                                     ThreeParConfig['connection'])
        SanitizerHash.default = %r{[^-\w]+}
      end

      def self.run(action, arguments)
        self.new.run(action, arguments)
      end

      def run(action, arguments)
        # TODO: create arugment parser and validator
        if parse_args(arguments) and validate_args(action)
          output = exec_cmd case action
            when :add_volume then
              create_volume(@snp, @usr, @name, @size)
            when :remove_volume then
              remove_volume(@volname)
            when :add_host then
              [create_host(@domain, @hostname),
              set_host(@os, @loc, @ip, @hostname)]
            when :export_volume then
              vlun_mgmt(:create, @volname, @lun, @hostname)
            when :unexport_volume then
              vlun_mgmt(:remove, @volname, @lun, @hostname)
            when :create_ro_snapshot then
              snap_mgmt(:ro, @comment, @snapname, @volname)
            when :create_rw_snapshot then
              [snap_mgmt(:ro, @comment, @snapname, @volname),
              snap_mgmt(:rw, @comment, @snapname, @snapname)]
            else
              raise BadAction
          end
          puts output.inspect
        else
          abort
        end
      end

      def create_host(domain, host)
        "createhost -iscsi -domain #{domain} -persona 1 -f #{host} #{iqn(host)}"
      end

      def set_host(os, loc, ip, hostname)
        "sethost -os {#{os}} -loc {#{loc}} -ip #{ip} #{hostname}"
      end

      def vlun_mgmt(action, volname, lun, hostname)
        raise BadAction unless [:create, :remove].include?(action)
        cmd = action.to_s + 'vlun' + (action == :remove ? ' -f' : '')
        "#{cmd} #{volname} #{lun} #{hostname}"
      end

      def create_volume(snp_cpg, usr_cpg, volname, volsize)
        "createvv -snp_cpg #{snp_cpg} #{usr_cpg} #{volname} #{volsize}"
      end

      def remove_volume(volname)
        "removevv -f #{volname}"
      end

      def create_snapshot(mode, volumename, snapname)
        # Steps:
        # generate comment
        # find volume, determine base id and snap count
        # generate snapshot name
        # determine if we need a intermediary volume:
        # if vol is diff than wanted:
        #  createsv -comment {comment} {snapname} {volname}
        # if vol is same as wanted, create intermediate volume
        # snap intermediate volume with:
        #  createsv -comment {comment} {snapname} {intermediaryvol}
        comment ||= 'This is a pre-generated comment'
      end

      def snap_mgmt(type, comment, dest, source)
        case type
          when :ro then
            "createsv -ro -comment {#{comment}} #{dest}.ro #{source}"
          when :rw then
            "createsv -comment {#{comment}} #{dest}.rw #{source}.ro"
          else
            raise BadSnapshotType
        end
      end

    protected

      def parse_args(args)
        args.each_pair do |name, value|
          instance_variable_set "@" + name.to_s, sanitize_arg(name, value)
        end
        true
      end

      def validate_args(action)
        #unless instance_variables.sort == ThreeParConfig.arguments[action].sort
          #raise MissingArgument
        #end
        true
      end

      def sanitize_arg(name, value)
        #puts "name=#{name.class};value=#{value.class}"
        value.gsub(/ /, '_').gsub(SanitizerHash[name], '')
      end

      def sanitize_cmd(command)
        "expr [#{command}]"
      end

    private
      def exec_cmd(cmds)
        cmds.each do |cmd|
          res = @ssh.exec(cmd)
          puts res.inspect
          raise Exception.new res[:ext_data] if res[:ext_type] == 1
        end
      end
      def iqn(host)
        ::CNU::Enki::Iscsi.generate_name(ThreeParConfig['config']['iqn'], host, 0)
      end
      #def get_base_id_from_volume_name(volumename)
        #o = exec_cmd('showvv -showcols BsId ' + volumename)[:data]
        #return o[:data][1].to_i if o[:data]
        #raise Exception.new('Invalid volume name provided')
      #end

      #def snapshot_name_generator( basename, mode)
        #VolumeName[0..(31-18)].(%04d[id]).(%04d[snamname]).r(o|w)
      #end

  end

end
