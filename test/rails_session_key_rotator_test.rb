require 'test_helper'

describe RailsSessionKeyRotator do
  include Rack::Test::Methods

  let(:session_data) { { user_id: 1 } }
  let(:old_secret) { "8aa8356b662857587b23adf45e742dc4ff99c0254da89e983b491b103911b2bbbc5494a9bd5e2b420ae4bd00029dc1f9959b8b70ec1c278cd3ccb758e6fd4aa5" }
  let(:new_secret) { "bd5dc20f2a7f7af27c137abde10ecaf0294eaa0a91e8c4c20995ae03d655cda7060b6ed178601a2eff8bf08f9423e4ebc08f2c3a077dba5647fb22f3f88c4090" }
  let(:key) { 'myapp_session' }
  let(:old_verifier) { ActiveSupport::MessageVerifier.new(old_secret) }
  let(:new_verifier) { ActiveSupport::MessageVerifier.new(new_secret) }
  let(:the_apps_session) { Marshal.load(last_response.body) }

  def app
    @app ||= begin
               builder = Rack::Builder.new
               builder.use RailsSessionKeyRotator, old_secret: old_secret, new_secret: new_secret, key: key
               builder.use ActionDispatch::Session::CookieStore, secret: new_secret, key: key
               builder.run proc { |env|
                 env["action_dispatch.secret_token"] = new_secret
                 request = ActionDispatch::Request.new(env)
                 cookie = request.cookie_jar.signed[key]
                 [200, {}, Marshal.dump(cookie) ]
               }
               builder.to_app
             end
  end

  context 'with a session cookie signed with the old secret' do
    before do
      rack_mock_session.cookie_jar[key] = old_verifier.generate(session_data)
    end

    it 're-writes the session cookie to be readable with the new secret by the app' do
      get '/'
      the_apps_session.must_equal(session_data)
    end
  end

  context 'with a session cookie signed with the new secret' do
    before do
      rack_mock_session.cookie_jar[key] = new_verifier.generate(session_data)
    end

    it 'does nothing (is still readable by the app)' do
      get '/'
      the_apps_session.must_equal(session_data)
    end
  end

  context 'with no session cookie' do
    before do
      rack_mock_session.cookie_jar[key] = nil
    end

    it 'does nothing (is read as nil by the app)' do
      get '/'
      the_apps_session.must_be_nil
    end
  end
end
