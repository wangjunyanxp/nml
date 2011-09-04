#!/usr/bin/env ruby

require 'fileutils'
require 'net/http'

def prepare(log, base)
  created_dir = Hash.new
  targets = Hash.new # key: link to download file, value: path to downloaded files

  re_url   = Regexp.compile 'GET\s+([\w\d:#@%/;$()~_?\+-=\\\.&]*)'
  re_base  = Regexp.compile '(.*)/([\w.\-]+\.(?:rpm|img))$'# current only cache rpm and *img*

  File.open(log, 'r').each do |l|
    if re_url =~ l
      url = $1

      if re_base =~ url
        skel, pkgname = $1, $2
        skel_dir = File.join(base, skel)
        skel_file = File.join(skel_dir, pkgname)
        
        # avoid duplicated download
        unless File.exists?(skel_file)
          # all the link in the targets hash will be download
          targets[url] = skel_file
        end
        
        # construct the skeleton directory for nginx
        # avoid repeated system call by in memory caching
        unless created_dir[skel]
             FileUtils.mkdir_p skel_dir
             created_dir[skel] = 1
        end
      end
    end
  end

  targets
end

def fetch(upstream, targets)
  succeed = 0

  Net::HTTP.start(upstream) do |http|
    targets.each_key do |k|
      resp = http.get(k)
      
      if resp.code.to_i != 200
        puts "#{k}: #{resp.code}"
      else
        if resp.class.body_permitted?
          File.open(targets[k], 'wb') do |f|
            f.write(resp.body)
          end
          succeed = succeed + 1
          puts "Okay: #{k}"
        else
          puts "#{k}: not body_permitted"
        end
      end
    end
  end

  succeed
end

succeed = fetch('mirrors.sdo.com', prepare(ARGV[0], '/opt/web/nml'))
puts "total: #{succeed}"
