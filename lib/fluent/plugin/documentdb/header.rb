require 'time'
require 'openssl'
require 'base64'
require 'erb'

module AzureDocumentDB

  class Header

    def initialize (master_key)
      @master_key = master_key
    end

    def generate (verb, resource_type, parent_resource_id, api_specific_headers = {} )
      headers = {}
      utc_date = get_httpdate()
      auth_token = generate_auth_token(verb, resource_type, parent_resource_id, utc_date )
      default_headers = { 
            'x-ms-version' => AzureDocumentDB::API_VERSION,
            'x-ms-date' => utc_date,
            'authorization' => auth_token 
            }.freeze
      headers.merge!(default_headers)
      headers.merge(api_specific_headers)
    end

    private
    
    def generate_auth_token ( verb, resource_type, resource_id, utc_date)
      payload = sprintf("%s\n%s\n%s\n%s\n%s\n",
                verb,
                resource_type,
                resource_id,
                utc_date,
                "" )
      sig = hmac_base64encode(payload)

      ERB::Util.url_encode sprintf("type=%s&ver=%s&sig=%s",
                AzureDocumentDB::AUTH_TOKEN_TYPE_MASTER,
                AzureDocumentDB::AUTH_TOKEN_VERSION,
                sig )
    end

    def get_httpdate
      Time.now.httpdate
    end

    def hmac_base64encode( text )
      key = Base64.urlsafe_decode64 @master_key
      hmac = OpenSSL::HMAC.digest('sha256', key, text.downcase)
      Base64.encode64(hmac).strip
    end

  end
end
