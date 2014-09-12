#!/usr/bin/env ruby

# Title:: Apache monitoring module for Zabbix
# License:: LGPL 2.1   http://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
# Copyright:: Copyright (C) 2014 Andrew Nelson nelsonab(at)red-tux(dot)net
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

require 'socket'

OUT_SOCKET="/var/lib/zabbix/apache-data-out"

# Ruby has no direct access to mkfifo(2). We use a shell script.
system '/bin/sh', '-c', <<EOF or abort
test -p #{OUT_SOCKET} || mkfifo #{OUT_SOCKET} || exit
EOF

# Forks a process to open _path_. Returns a _socket_ to receive the open
# IO object (by UNIXSocket#recv_io).
def open_sesame(path, mode)
  reader, writer = UNIXSocket.pair
  pid = fork do
    begin
      reader.close
      file = File.open(path, mode)
      writer.send_io file
    ensure
      exit!
    end
  end
  Process.detach pid
  writer.close
  return reader
end

class IO
  def readline_nonblock
    rlnb_buffer = ""
    while ch = self.read_nonblock(1)
      rlnb_buffer << ch
      if ch == "\n" then
        result = rlnb_buffer
        return result
      end
    end
  end
end

counter_received=0
counter_sent=0
total_time=0
total_microseconds=0

outsock = open_sesame(OUT_SOCKET, "w")
outpipe = nil
str=""
count=0
connections = [outsock,STDIN]
loop do
  selection=select(connections,[],[],1)
  if !selection.nil? then
    selection[0].each do |connection|
      case connection.class.to_s
      when "UNIXSocket"
        outpipe = connection.recv_io
        connection.close
        connections.delete connection
        outpipe.puts "Count Received Sent total_time  total_microsedonds"
        outpipe.puts "#{count} #{counter_received} #{counter_sent} #{total_time} #{total_microseconds}"
        outpipe.close
        connections.push open_sesame(OUT_SOCKET, "w")
      when "IO"
        count+=1
        data=connection.readline_nonblock.split
        counter_received+=data[2].to_i
        counter_sent+=data[3].to_i
        total_time+=data[4].to_i
        total_microseconds+=data[5].to_i
      end
    end
  end
end
