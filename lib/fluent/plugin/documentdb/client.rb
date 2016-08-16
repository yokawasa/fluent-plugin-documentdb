require 'rest-client'
require 'json'
require_relative 'constants'
require_relative 'header'
require_relative 'resource'

module AzureDocumentDB

  class Client

    def initialize (master_key, url_endpoint)
      @master_key = master_key
      @url_endpoint = url_endpoint
      @header = AzureDocumentDB::Header.new(@master_key)
    end

    def create_database (database_name)
      url = "#{@url_endpoint}/dbs"
      custom_headers = {'Content-Type' => 'application/json'}
      headers = @header.generate('post', AzureDocumentDB::RESOURCE_TYPE_DATABASE, '', custom_headers )
      body_json = { 'id' => database_name }.to_json
      res = RestClient.post( url, body_json, headers)
      JSON.parse(res)
    end

    def find_databases_by_name (database_name)
      query_params = []
      query_text = "SELECT * FROM root r WHERE r.id=@id"
      query_params.push( {:name=>"@id", :value=> database_name } )
      url = sprintf("%s/dbs", @url_endpoint )
      res = _query(AzureDocumentDB::RESOURCE_TYPE_DATABASE, '', url, query_text, query_params)
      res 
    end

    def get_database_resource (database_name) 
      resource  = nil
      res = find_databases_by_name (database_name)
      if( res[:body]["_count"].to_i == 0 )
        p "no #{database_name} database exists"
        return resource
      end
      res[:body]['Databases'].select do |db| 
        if (db['id'] == database_name )
          resource = AzureDocumentDB::DatabaseResource.new(db['_rid'])
        end
      end
      resource
    end

    def create_collection(database_resource, collection_name, colls_options={}, custom_headers={} )
      if !database_resource 
        raise ArgumentError.new 'No database_resource!'
      end
      url = sprintf("%s/dbs/%s/colls", @url_endpoint, database_resource.database_rid )
      custom_headers['Content-Type'] = 'application/json'
      headers = @header.generate('post',
            AzureDocumentDB::RESOURCE_TYPE_COLLECTION,
            database_resource.database_rid, custom_headers )
      body = {'id' => collection_name }
      colls_options.each{|k, v|
        if k == 'indexingPolicy' || k == 'partitionKey'
          body[k] = v
        end
      }
      res = RestClient.post( url, body.to_json, headers)
      JSON.parse(res)
    end

    def find_collections_by_name(database_resource, collection_name)
      if !database_resource 
        raise ArgumentError.new 'No database_resource!'
      end
      ret = {}
      query_params = []
      query_text = "SELECT * FROM root r WHERE r.id=@id"
      query_params.push( {:name=>"@id", :value=> collection_name } )
      url = sprintf("%s/dbs/%s/colls", @url_endpoint, database_resource.database_rid)
      ret = _query(AzureDocumentDB::RESOURCE_TYPE_COLLECTION,
                database_resource.database_rid, url, query_text, query_params)
      ret
    end

    def get_collection_resource (database_resource, collection_name)
      _collection_rid = ''
      if !database_resource 
        raise ArgumentError.new 'No database_resource!'
      end
      res = find_collections_by_name(database_resource, collection_name)
      res[:body]['DocumentCollections'].select do |col| 
        if (col['id'] == collection_name )
          _collection_rid = col['_rid']
        end
      end
      if _collection_rid.empty?
        p "no #{collection_name} collection exists"
        return nil
      end
      AzureDocumentDB::CollectionResource.new(database_resource.database_rid, _collection_rid)      
    end
    
    def create_document(collection_resource, document_id, document, custom_headers={} )
      if !collection_resource 
        raise ArgumentError.new 'No collection_resource!'
      end
      if document['id'] && document_id != document['id'] 
        raise ArgumentError.new "Document id mismatch error (#{document_id})!"
      end
      body = { 'id' => document_id }.merge document
      url = sprintf("%s/dbs/%s/colls/%s/docs",
                  @url_endpoint, collection_resource.database_rid, collection_resource.collection_rid)
      custom_headers['Content-Type'] = 'application/json'
      headers = @header.generate('post', AzureDocumentDB::RESOURCE_TYPE_DOCUMENT,
                                  collection_resource.collection_rid, custom_headers )
      res = RestClient.post( url, body.to_json, headers)
      JSON.parse(res)
    end

    def find_documents(collection_resource, document_id, custom_headers={})
      if !collection_resource 
        raise ArgumentError.new 'No collection_resource!'
      end
      ret = {}
      query_params = []
      query_text = "SELECT * FROM c WHERE c.id=@id"
      query_params.push( {:name=>"@id", :value=> document_id } )
      url = sprintf("%s/dbs/%s/colls/%s/docs",
              @url_endpoint, collection_resource.database_rid, collection_resource.collection_rid)
      ret = _query(AzureDocumentDB::RESOURCE_TYPE_DOCUMENT,
              collection_resource.collection_rid, url, query_text, query_params, custom_headers)
      ret
    end

    def query_documents( collection_resource, query_text, query_params, custom_headers={} )
      if !collection_resource 
        raise ArgumentError.new 'No collection_resource!'
      end
      ret = {}
      url = sprintf("%s/dbs/%s/colls/%s/docs",
              @url_endpoint, collection_resource.database_rid, collection_resource.collection_rid)
      ret = _query(AzureDocumentDB::RESOURCE_TYPE_DOCUMENT,
              collection_resource.collection_rid, url, query_text, query_params, custom_headers)
      ret
    end

    protected

    def _query( resource_type, parent_resource_id, url, query_text, query_params, custom_headers={} )
      query_specific_header = {
              'x-ms-documentdb-isquery' => 'True',
              'Content-Type' => 'application/query+json',
              'Accept' => 'application/json'
             }
      query_specific_header.merge! custom_headers
      headers = @header.generate('post', resource_type, parent_resource_id, query_specific_header)
      body_json = {
              :query => query_text,
              :parameters => query_params
             }.to_json

      res = RestClient.post( url, body_json, headers) 
      result = {
          :header => res.headers,
          :body => JSON.parse(res.body) }
      return result
    end
  end
end
