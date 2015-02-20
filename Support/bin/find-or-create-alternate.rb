#!/usr/bin/env ruby

abort "This program requires an MRI Ruby" unless RUBY_ENGINE == 'ruby'

require 'pathname'

module FindOrCreateAlternate

	SUPPORT_DIR = Pathname( ENV['TM_SUPPORT_PATH'] )
	SUPPORT_BIN = SUPPORT_DIR + 'bin'

	MATE = ENV['TM_MATE']
	DIALOG = ENV['DIALOG']


	###############
	module_function
	###############

	### Run the switcher.
	def run( source_file, project_dir )
		source_file = Pathname( source_file )
		project_dir = Pathname( project_dir )

		relpath = source_file.relative_path_from( project_dir )
		alternate = find_alternate( project_dir, relpath )

		unless alternate.exist?
			msg = "The file '%s' doesn't exist. Create it?" % [ alternate ]
			ans = ask_for_confirmation( 'Alternate Spec and Source', msg )
			exit unless ans
		end

		type = 'source.ruby'
		type += '.rspec' if alternate.to_s.end_with?( '_spec.rb' )

		exec MATE, '--async', '--type', type, alternate.to_s
	rescue => err
		message = "<b>%p</b> while switching: <b>%s</b> (%s)<br>" %
			[ err.class, err.message, RUBY_DESCRIPTION ]
		err.backtrace.each do |frame|
			message << "  <code>" << frame << "</code><br>"
		end

		tooltip( message )
		exit 0
	end


	### Return the alternate file for +relpath+
	def find_alternate( project_dir, relpath )
		components = relpath.each_filename.to_a
		topdir = components.shift

		case topdir
		when 'spec'
			filename = components.pop.sub( %r{_spec\.rb$}, '.rb' )
			return project_dir + 'lib' + components.join( File::SEPARATOR ) + filename
		when 'lib'
			filename = components.pop.sub( %r{\.rb$}, '_spec.rb' )
			return project_dir + 'spec' + components.join( File::SEPARATOR ) + filename
		else
			raise "Don't know what kind of file '%s' is." % [ relpath ]
		end
	end


	### Show a tooltip with the specified +message+.
	def tooltip( message )
		system DIALOG, 'tooltip', '--html', message
	end


	### Present a dialog asking for confirmation of +message+, and return +true+ if the user
	### accepted.
	def ask_for_confirmation( title, message )
		cmd = [
			DIALOG, 'alert',
			 '--alertStyle', 'warning',
			 '--title', title,
			 '--body', message,
			 '--button1', 'Okay',
			 '--button2', 'Cancel'
		]

		reader, writer = IO.pipe
		pid = spawn( *cmd, [:out, :err] => writer )
		writer.close
		Process.waitpid2( pid )
		plist = reader.read

		answer = plist[ %r{<key>buttonClicked</key>\s+<integer>(\d+)</integer>}m, 1 ]

		return answer == '0'
	end

end


FindOrCreateAlternate.run( *ARGV )