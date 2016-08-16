module AzureDocumentDB
  API_VERSION = '2015-12-16'.freeze
  RESOURCE_TYPE_DATABASE='dbs'.freeze
  RESOURCE_TYPE_COLLECTION='colls'.freeze
  RESOURCE_TYPE_DOCUMENT='docs'.freeze
  AUTH_TOKEN_VERSION = '1.0'.freeze
  AUTH_TOKEN_TYPE_MASTER = 'master'.freeze
  AUTH_TOKEN_TYPE_RESOURCE = 'resource'.freeze
  PARTITIONED_COLL_MIN_THROUGHPUT = 10100.freeze
end
