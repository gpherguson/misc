#!/usr/bin/env ruby -wKU

require 'rubygems'
require 'digest'
require 'net/http'
require 'uri'
require 'xmlsimple'

# http://lukaszpelszynski.blogspot.com/2009/09/facebook-rest-api-hackers-way.html

def request(params, secret_key = API_SECRET, secure = TRUE)
  api_url = URI.parse("#{ (secure ? 'https' : 'http') }://#{API_PATH}")
  unless params.has_key?('method')
    raise "'method' is required for making a request."
  end
  params[ 'api_key' ] = APP_KEY
  params[ 'call_id' ] = Time.new.to_f.to_s
  params[ 'v'       ] = '1.0'
  params[ 'format'  ] = 'xml'
  params_str          = params.sort.map! { |p| "#{ p[0] }=#{ p[1] }" }.join
  params[ 'sig'     ] = Digest::MD5.hexdigest(params_str + secret_key)
  
  req = Net::HTTP::Post.new(api_url.path)
  req.set_form_data(params)
  connection = Net::HTTP.new(api_url.host, api_url.port)
  if api_url.scheme == 'https'
    connection.use_ssl     = true
    connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  connection.request(req).body
end

# Then open a web browser. Our browser is called CURL and it supports cookies.
# Great.
# 
# You must pass special 'lsd' parameter to POST, look for it in your cookie
# file when you visit facebook.com/login.php.
def web_login(auth_token)
  get_session(auth_token) #visit login.php :)
  lsd = get_cookie_data("lsd")
  exec("curl -L -b #{ COOKIE_FILE } -c #{ COOKIE_FILE } -A \"#{ BROWSER }\" \
    -d \"?auth_token=#{ auth_token }&api_key=#{ APP_KEY }&lsd=#{ lsd }& \
    email=#{ URI.encode(@email) }&pass=#{ URI.encode(@password) }\" \
    https://login.facebook.com/login.php > #{ TOKEN_FILE }" ) if fork == nil
  Process.wait
  get_token
end

# "get_token" parses TOKEN_FILE. This is html file redirecting us to homepage.
# It contains... the second token!
def get_token
  xml     = XmlSimple.xml_in(TOKEN_FILE)
  content = xml['head'][0]['meta'][0]['content']
  File.delete(TOKEN_FILE) if File.exists?(TOKEN_FILE)
  content.match(/auth_token=(\w+)/)[1]
end

# Then you're ready to make authorized requests. Overwrite you old secret with
# @secret and use your session_key.
def authorized_request(params)
  params['session_key'] = @session_key
  request(params, @secret)
end

# Get first token just like this:
token_xml  = XmlSimple.xml_in request( 'method' => 'facebook.auth.createToken')
auth_token = token_xml['content']

# It's time to get session parameters.
session_xml = XmlSimple.xml_in request({ 
  'method'     => 'facebook.auth.getSession', 
  'auth_token' => session_auth_token
  })
@uid         = session_xml['uid'][0]
@secret      = session_xml['secret'][0]
@session_key = session_xml['session_key'][0]


# Now gates to Facebook are wide open.
