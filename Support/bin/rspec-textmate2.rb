#!/usr/bin/env ruby
#encoding: utf-8

require 'pathname'
require 'rbconfig'
require 'erb'
require 'logger'
require 'shellwords'

$log = Logger.new( '/tmp/rspec3.log' )

TM_PROJECT_DIRECTORY = Pathname( ENV['TM_PROJECT_DIRECTORY'] || Dir.pwd )
TM_BUNDLE_SUPPORT    = Pathname( __FILE__ ).dirname.parent
SUPPORT_LIBDIR       = TM_BUNDLE_SUPPORT + 'lib'
SUPPORT_DATADIR      = TM_BUNDLE_SUPPORT + 'data/rspec-formatter-webkit'
SUPPORT_TEMPLATEDIR  = SUPPORT_DATADIR + 'templates'

ERROR_TEMPLATE       = SUPPORT_TEMPLATEDIR + 'error.rhtml'

RSPEC_OPTS           = ENV['TM_RSPEC_OPTS'] || '-rrspec/core/formatters/webkit'
RSPEC_FORMATTER      = ENV['TM_RSPEC_FORMATTER'] || 'RSpec::Core::Formatters::WebKit'

BASE_HREF            = "file://#{SUPPORT_DATADIR}/"

RUBY = RbConfig.ruby

def main( args )
	rspec_args = Shellwords.shellsplit( RSPEC_OPTS ) +
		 ['-f'] +
		 Shellwords.shellsplit( RSPEC_FORMATTER ) +
		 ['--failure-exit-code', '127']

	if ENV['RSPEC_SEED']
		rspec_args += [
			'--seed', ENV['RSPEC_SEED']
		]
	end

	files = args.map do |path|
		# Strip single quotes
		path = path[ 1..-2 ] if path.start_with?( "'" )
		rspec_args << path
	end

	$log.debug "Running: RUBYLIB=#{SUPPORT_LIBDIR} #{RUBY} -S rspec #{rspec_args.join(' ')}"
	ENV['RUBYLIB'] = SUPPORT_LIBDIR.to_s
	$stdout.sync = true
	r, w = IO.pipe
	reader = Thread.new { r.read }
	system( RUBY, '-S', 'rspec', *rspec_args, STDERR => w )
	w.close
	status = $?

	unless status.success? || status.exitstatus == 127
		stderr = reader.value
		$log.error "RSpec exited with %p" % [ status ]
		$log.debug( stderr )
		message = "RSpec process #{status.pid} exited with code #{status.exitstatus}\n"
		error_page( message + stderr )
	end

	return 0
rescue => err
	message = "%p occurred while wrapping rspec: %s\n" % [ err.class, err.message ]
	message << err.backtrace.join( "\n  " )
	error_page( message )

	return 0
end


def error_page( message )
	include ERB::Util
	template = ERB.new( ERROR_TEMPLATE.read, nil, '%<>' ).freeze
	puts template.result( binding() )
end

$log.info "Starting up the rspec3 wrapper."
exit main( ARGV )

