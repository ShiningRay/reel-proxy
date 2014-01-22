# A sample Guardfile
# More info at https://github.com/guard/guard#readme

# This is an example with all options that you can specify for guard-process
guard :process, :name => 'server', :command => 'ruby src/server.rb', :stop_signal => "KILL"  do
  watch('Gemfile.lock')
  watch(/.rb$/)
end


guard :bundler do
  watch('Gemfile')
  # Uncomment next line if your Gemfile contains the `gemspec' command.
  # watch(/^.+\.gemspec/)
end
