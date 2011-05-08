module CNU::Gozer

  require "#{File.dirname(__FILE__)}/san_types/three_par.rb"
  require "#{File.dirname(__FILE__)}/san_types/equal_logic.rb"

  class SanCmdRunner

    class BadTypeException < Exception; end
 
    attr_accessor :san
  
    def initialize(type)
      if type == '3par'
        @san = SanTypes::ThreePar.new
      elsif type == 'equallogic'
        @san = SanTypes::EqualLogic.new
      else
        raise SanBadTypeException, "Don't know how to work on #{san.type}"
      end
    end

    def self.add_volume(san, *args)
      self.new(san).add_volume(*args)
    end

    def add_volume(*args)
      @san.run(:add_volume, *args)
    end 

    def self.add_host(san, *args)
      self.new(san).add_host(*args)
    end

    def add_host(*args)
      @san.run(:add_host, *args)
    end

    def self.export_volume(san, *args)
      self.new(san).export_volume(*args)
    end

    def export_volume(*args)
      @san.run(:export_volume, *args)
    end

    def self.unexport_volume(san, *args)
      self.new(san).unexport_volume(*args)
    end

    def unexport_volume(*args)
      @san.run(:unexport_volume, *args)
    end

    def self.create_rw_snapshot(san, *args)
      self.new(san).create_rw_snapshot(*args)
    end

    def create_rw_snapshot(*args)
      @san.run(:create_rw_snap, *args)
    end

    def self.create_ro_snapshot(san, *args)
      self.new(san).create_ro_snapshot(*args)
    end

    def create_ro_snapshot(*args)
      @san.run(:create_ro_snap, *args)
    end

  end
end
