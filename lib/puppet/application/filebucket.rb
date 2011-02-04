require 'puppet/application'

class Puppet::Application::Filebucket < Puppet::Application

  should_not_parse_config

  option("--bucket BUCKET","-b")
  option("--debug","-d")
  option("--local","-l")
  option("--remote","-r")
  option("--verbose","-v")

  attr :args

  def help
    <<-HELP

SYNOPSIS
========
A stand-alone Puppet filebucket client.


USAGE
=====
  puppet filebucket [-h|--help] [-V|--version] [-d|--debug] [-v|--verbose]
     [-l|--local] [-r|--remote]
     [-s|--server <server>] [-b|--bucket <directory>] <file> <file> ...


DESCRIPTION
===========
This is a stand-alone filebucket client for sending files to a local or
central filebucket.


USAGE
=====
This client can operate in three modes, with only one mode per call:

backup:  Send one or more files to the specified file bucket. Each sent
         file is printed with its resulting md5 sum.

get:     Return the text associated with an md5 sum. The text is printed
         to stdout, and only one file can be retrieved at a time.

restore: Given a file path and an md5 sum, store the content associated
         with the sum into the specified file path. You can specify an
         entirely new path to this argument; you are not restricted to

Note that 'filebucket' defaults to using a network-based filebucket
available on the server named 'puppet'. To use this, you'll have to be
running as a user with valid Puppet certificates. Alternatively, you can
use your local file bucket by specifying '--local'.


EXAMPLE
=======
  $ puppet filebucket backup /etc/passwd
  /etc/passwd: 429b225650b912a2ee067b0a4cf1e949
  $ puppet filebucket restore /tmp/passwd 429b225650b912a2ee067b0a4cf1e949
  $


OPTIONS
=======
Note that any configuration parameter that's valid in the configuration
file is also a valid long argument. For example, 'ssldir' is a valid
configuration parameter, so you can specify '--ssldir <directory>' as an
argument.

See the configuration file documentation at
http://docs.puppetlabs.com/references/stable/configuration.html for the
full list of acceptable parameters. A commented list of all
configuration options can also be generated by running puppet with
'--genconfig'.

debug:   Enable full debugging.

help:    Print this help message

local:   Use the local filebucket. This will use the default
         configuration information.

remote:  Use a remote filebucket. This will use the default
         configuration information.

server:  The server to send the file to, instead of locally.

verbose: Print extra information.

version: Print version information.


EXAMPLE
=======
  puppet filebucket -b /tmp/filebucket /my/file


AUTHOR
======
Luke Kanies


COPYRIGHT
=========
Copyright (c) 2005 Puppet Labs, LLC Licensed under the GNU Public
License

    HELP
  end


  def run_command
    @args = command_line.args
    command = args.shift
    return send(command) if %w{get backup restore}.include? command
    help
  end

  def get
    md5 = args.shift
    out = @client.getfile(md5)
    print out
  end

  def backup
    args.each do |file|
      unless FileTest.exists?(file)
        $stderr.puts "#{file}: no such file"
        next
      end
      unless FileTest.readable?(file)
        $stderr.puts "#{file}: cannot read file"
        next
      end
      md5 = @client.backup(file)
      puts "#{file}: #{md5}"
    end
  end

  def restore
    file = args.shift
    md5 = args.shift
    @client.restore(file, md5)
  end

  def setup
    Puppet::Log.newdestination(:console)

    @client = nil
    @server = nil

    trap(:INT) do
      $stderr.puts "Cancelling"
      exit(1)
    end

    if options[:debug]
      Puppet::Log.level = :debug
    elsif options[:verbose]
      Puppet::Log.level = :info
    end

    # Now parse the config
    Puppet.parse_config

      exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    require 'puppet/file_bucket/dipper'
    begin
      if options[:local] or options[:bucket]
        path = options[:bucket] || Puppet[:bucketdir]
        @client = Puppet::FileBucket::Dipper.new(:Path => path)
      else
        @client = Puppet::FileBucket::Dipper.new(:Server => Puppet[:server])
      end
    rescue => detail
      $stderr.puts detail
      puts detail.backtrace if Puppet[:trace]
      exit(1)
    end
  end

end

