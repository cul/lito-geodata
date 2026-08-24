lock "~> 3"

set :application, "geodata"
set :repo_url, 'git@github.com:cul/lito-geodata.git'

ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

append :linked_files, 'config/database.yml',
                      'config/blacklight.yml',
                      'config/app_config.yml', 
                      'config/cas.yml',
                      'config/master.key'

append :linked_dirs, 'log', 'tmp', 'public/metadata', 'public/opengeometadata'

set :passenger_restart_with_touch, true