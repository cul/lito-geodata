# Use this file to easily define all of your cron jobs.
# Learn more: http://github.com/javan/whenever

# Load rails environment
require File.expand_path('../config/environment', __dir__)

# Set environment to current environment.
set :environment, Rails.env

# Give our jobs nice subject lines
set :subject, 'cron output'
set :recipient, 'geodata@library.columbia.edu'
set :job_template, "/usr/local/bin/mailifoutput -s ':subject (:environment)' :recipient /bin/bash -l -c ':job'"

# Rake jobs need to use the appropriate version of Ruby commands
set :bundle_command, 'undefined'

if @environment == 'geodata_dev'
  set :bundle_command, '~/.rvm/wrappers/geodata_dev/bundle exec'
end

if @environment == 'geodata_test'
  set :bundle_command, '~/.rvm/wrappers/geodata_test/bundle exec'
end

if @environment == 'geodata_prod'
  set :bundle_command, '~/.rvm/wrappers/geodata_prod/bundle exec'
end

# Run on every host - dev, test, prod
every :day, at: '1am' do
  rake 'metadata:process', subject: 'GeoData metadata:process'
end

every :day, at: '2am' do
  rake 'opengeometadata:process', subject: 'GeoData opengeometadata:process'
end



# Examples of per-environment cron commands
# 
# if @environment == "geoblacklight_dev"
#     every :weekday, :at => '10pm' do
#         # rake "foo:bar"
#     end
# end
# 
# if @environment == "geoblacklight_test"
#     every :weekend, :at => '0:0am' do
#         # rake "arf:meow"
#     end
# end