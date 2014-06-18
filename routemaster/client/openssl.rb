# In development environments, engineers will typically use self-signed
# certificates as it it not realistic to have valid cert chains for localhost
# or fake domains.
#
# This code disables SSL cert verification, and silences net-http-persistent's
# unnecessary warning.
#
# Note that this does _not_ apply in production or staging.
#
# http://docs.seattlerb.org/net-http-persistent/History_txt.html#documentation
# http://www.rubyinside.com/how-to-cure-nethttps-risky-default-https-behavior-4010.html
if ENV.fetch('RACK_ENV', 'development') !~ /production|staging/
  require 'openssl'
  require 'core_ext/silence_stream'

  I_KNOW_THAT_OPENSSL_VERIFY_PEER_EQUALS_VERIFY_NONE_IS_WRONG = nil

  $stderr.silence_stream do
    OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
  end
end
