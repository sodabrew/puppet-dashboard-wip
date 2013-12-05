# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.12' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')
require 'active_support'

require 'registry'

require 'core_callbacks'

Rails::Initializer.run do |config|
  config.gem 'rack'
  config.gem 'haml'
  config.gem 'sass'
  config.gem 'will_paginate'
  config.gem 'daemons', :version => '1.0.10'

  # Settings in config/environments/* take precedence over those specified here.
  # Application configuration should go into files in config/initializers
  # -- all .rb files in that directory are automatically loaded.

  # Add additional load paths for your own custom dirs
  config.autoload_paths += %W( #{RAILS_ROOT}/app/mixins )
  Dir["#{RAILS_ROOT}/vendor/gems/**"].each do |dir|
    config.autoload_paths.unshift(File.directory?(lib = "#{dir}/lib") ? lib : dir)
  end

  # Specify gems that this application depends on and have them installed with rake gems:install
  # config.gem "bj"
  # config.gem "hpricot", :version => '0.6', :source => "http://code.whytheluckystiff.net"
  # config.gem "sqlite3-ruby", :lib => "sqlite3"
  # config.gem "aws-s3", :lib => "aws/s3"

  # Only load the plugins named here, in the order given (default is alphabetical).
  # :all can be used as a placeholder for all plugins not explicitly named
  # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

  # Skip frameworks you're not going to use. To use Rails without a database,
  # you must remove the Active Record framework.
  # config.frameworks -= [ :active_record, :active_resource, :action_mailer ]

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

  # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
  # Run "rake -D time" for a list of tasks for finding time zone names.
  # The user can override this in config/settings.yml.
  config.time_zone = 'UTC'

  # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
  # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}')]
  # config.i18n.default_locale = :de
end

ActiveRecord::Base.include_root_in_json = false
require 'safe_yaml'
# Set default for YAML.load to unsafe so we don't affect performance
# unnecessarily -- we call it safely explicitly where needed
SafeYAML::OPTIONS[:default_mode] = :unsafe
# Whitelist Symbol objects
# NOTE that the tag is YAML implementation specific (this one is
# specific to 'syck') and thus it needs to be updated whenever
# the yaml implementation is changed
SafeYAML::OPTIONS[:whitelisted_tags] << 'tag:ruby.yaml.org,2002:sym'

