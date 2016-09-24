$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'shameless'

Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each {|file| puts file; require file }
