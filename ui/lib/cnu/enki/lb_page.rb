#!/usr/bin/ruby 

module CNU::Enki

include CNU::Enki::ConfigLayout

class LbPage 

public
def self.generate(directory)
    t = Time.now()
    new().generate(directory) 
    print_runtime(t,'Load Balancer Pages')
end
def dump_route(url, filename)
    app.get(url) 
    File.open(filename,'w') do |io|
      io.puts app.html_document.root.to_s
    end
end
def dump_route_file(base, urlpath, directory)
    app.get("#{urlpath}/#{base}") 
    File.open(File.join(directory, base),'w') do |io|
      io.puts app.html_document.root.to_s
    end
end
def copy_code(filename, src, dest)
  FileUtils.cp(src.join(filename), dest)
end
def generate(dir)
    require "console_app"
    dump_route('status/cluster.js', File.join(dir ,'clusters.json') )
end

end

end # end module
