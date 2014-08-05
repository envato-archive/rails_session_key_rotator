require 'rubygems'
require 'bundler/setup'

require 'minitest/autorun'
$:.unshift 'lib'

require 'rails_session_key_rotator'
require 'rack/test'
require 'pry'

class MiniTest::Spec
  class << self
    alias context describe
  end
end
