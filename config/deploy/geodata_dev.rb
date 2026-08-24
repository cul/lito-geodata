server 'lito-rails-dev1.cul.columbia.edu', user: 'litoserv', roles: %w{app db web}
set :deploy_to, '/opt/passenger/geodata_dev'
set :rvm_ruby_version, 'geodata_dev'