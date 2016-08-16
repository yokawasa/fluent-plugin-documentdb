require 'rest-client'
require 'json'
require_relative 'constants'
require_relative 'header'
require_relative 'resource'

module AzureDocumentDB

  class PartitionedCollectionClient < Client

    def create_collection(database_resource, collection_name,
          partition_key_paths, offer_throughput = AzureDocumentDB::PARTITIONED_COLL_MIN_THROUGHPUT )

      if (offer_throughput <  AzureDocumentDB::PARTITIONED_COLL_MIN_THROUGHPUT) 
        raise ArgumentError.new sprintf("Offeer thoughput need to be more than %d !",
                          AzureDocumentDB::PARTITIONED_COLL_MIN_THROUGHPUT)
      end 
      if (partition_key_paths.length < 1 )
        raise ArgumentError.new "No PartitionKey paths!"
      end
      colls_options = {
            'indexingPolicy' => { 'indexingMode' => "consistent", 'automatic'=>true },
            'partitionKey' => { "paths" => partition_key_paths, "kind" => "Hash" }
      }
      custom_headers= {'x-ms-offer-throughput' => offer_throughput }
      super(database_resource, collection_name, colls_options, custom_headers)
    end


    def create_document(collection_resource, document_id, document, partitioned_key )
      if partitioned_key.empty?
        raise ArgumentError.new "No partitioned key!"
      end
      if !document.key?(partitioned_key)
        raise ArgumentError.new "No partitioned key in your document!"
      end
      partitioned_key_value = document[partitioned_key]
      custom_headers = {
          'x-ms-documentdb-partitionkey' => "[\"#{partitioned_key_value}\"]"
        }
      super(collection_resource, document_id, document, custom_headers) 
    end

    def find_documents(collection_resource, document_id,
                partitioned_key, partitioned_key_value, custom_headers={})
      if !collection_resource 
        raise ArgumentError.new "No collection_resource!"
      end
      ret = {}
      query_params = []
      query_text = sprintf("SELECT * FROM c WHERE c.id=@id AND c.%s=@value", partitioned_key)
      query_params.push( {:name=>"@id", :value=> document_id } )
      query_params.push( {:name=>"@value", :value=> partitioned_key_value } )
      url = sprintf("%s/dbs/%s/colls/%s/docs",
              @url_endpoint, collection_resource.database_rid, collection_resource.collection_rid)
      ret = query(AzureDocumentDB::RESOURCE_TYPE_DOCUMENT,
              collection_resource.collection_rid, url, query_text, query_params, custom_headers)
      ret
    end

  end
end
