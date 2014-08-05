require 'rack'
require 'action_dispatch'

class RailsSessionKeyRotator
  def initialize(app, options = {})
    @app = app
    @session_cookie_key = options.fetch(:key)
    @old_secret = options.fetch(:old_secret)
    @new_secret = options.fetch(:new_secret)
  end

  def call(env)
    @request = Rack::Request.new(env)
    if session_cookie.present? && old_signature_matches?
      @request.cookies[@session_cookie_key] = new_verifier.generate(session_data)
      ActiveSupport::Notifications.instrument('rails_session_key_rotator.upgraded', @request)
    end
    @app.call(env)
  end

  private

  def session_cookie
    @request.cookies[@session_cookie_key]
  end

  def old_signature_matches?
    !!session_data
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    false
  end

  def session_data
    @session_data ||= old_verifier.verify(session_cookie)
  end

  def old_verifier
    @old_verifier ||= ActiveSupport::MessageVerifier.new(@old_secret)
  end

  def new_verifier
    @new_verifier ||= ActiveSupport::MessageVerifier.new(@new_secret)
  end
end
