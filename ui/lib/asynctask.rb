class Asynctask
end

module JobTasks
  def worker_queue(name)
      x = name.to_sym.inspect 
      self.class_eval "def self.queue() return #{x}; end"
      return name
  end
end
module ScriptTasks 
  def script_name(script_fn, *params)
       define_method(:script) { 
            unless File.stat(script_fn).executable?  then
                raise Exception.new("unexecutable #{script_fn}") 
            end
            return script_fn 
      }
      define_method(:script_args) { return params }
      script_fn # "/path/to/something"
  end
  def parameter_parsing(arg_hash)
    s =  []; j=[]
    if arg_hash.key?(:script_args) then
      s = arg_hash[:script_args]
    end
    if arg_hash.key?(:job_args) then
      j = arg_hash[:job_args]
    end
    return s.concat(j).flatten
  end
  def run_script(script, job_args)
    args = parameter_parsing(job_args)
    fn = File.basename(script)
    cmd = %Q(#{script} #{args.join(' ')} 2>&1) 

    puts "Running '#{cmd}'" if $VERBOSE
    out = IO.popen(cmd,'r') {|io|
      output = ["Output from #{fn}"]
      while not io.eof?
        item = io.readline
        #output << "#{fn}:0 #{item.chomp}"
        output << item 
      end
      output 
    }
    rc = $?
    if rc.exitstatus == 0 then
      return true
    else
      ex = Exception.new("Failed (#{rc.exitstatus}) for #{fn}")
      ex.set_backtrace(out)
      raise ex
    end
  end
  def perform(*args)
      x = new()
      if args.nil? then
        run_script(x.script, :script_args => x.script_args)
      else
        run_script(x.script, :script_args => x.script_args, :job_args => args)
      end
  end
end

class ItCfgTask 
  extend JobTasks
  worker_queue :itcfg
end
class ScriptTask < ItCfgTask
  extend ScriptTasks
end
class PduPush < ScriptTask
   script_name '/usr/bin/push-itcfg', '-p'
end

class ScsPush < ScriptTask
   script_name '/usr/bin/push-itcfg', '-s'
end
