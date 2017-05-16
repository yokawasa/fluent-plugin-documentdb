# -*- coding: utf-8 -*-

module Fluent

  require 'fluent/plugin/documentdb/constants'

  class DocumentdbOutput < BufferedOutput
    Plugin.register_output('documentdb', self)

    unless method_defined?(:log)
      define_method('log') { $log }
    end

    def initialize
      super
      require 'msgpack'
      require 'time'
      require 'securerandom'
      require 'fluent/plugin/documentdb/client'
      require 'fluent/plugin/documentdb/partitioned_coll_client'
      require 'fluent/plugin/documentdb/header'
      require 'fluent/plugin/documentdb/resource'
    end

    config_param :docdb_endpoint, :string
    config_param :docdb_account_key, :string, :secret => true
    config_param :docdb_database, :string
    config_param :docdb_collection, :string
    config_param :auto_create_database, :bool, :default => true
    config_param :auto_create_collection, :bool, :default => true
    config_param :partitioned_collection, :bool, :default => false
    config_param :partition_key, :string, :default => nil
    config_param :offer_throughput, :integer, :default => AzureDocumentDB::PARTITIONED_COLL_MIN_THROUGHPUT
    config_param :time_format, :string, :default => nil
    config_param :localtime, :bool, :default => false
    config_param :add_time_field, :bool, :default => true
    config_param :time_field_name, :string, :default => 'time'
    config_param :add_tag_field, :bool, :default => false
    config_param :tag_field_name, :string, :default => 'tag'

    def configure(conf)
      super
      raise ConfigError, 'no docdb_endpoint' if @docdb_endpoint.empty?
      raise ConfigError, 'no docdb_account_key' if @docdb_account_key.empty?
      raise ConfigError, 'no docdb_database' if @docdb_database.empty?
      raise ConfigError, 'no docdb_collection' if @docdb_collection.empty?
      if @add_time_field and @time_field_name.empty?
        raise ConfigError, 'time_field_name must be set if add_time_field is true'
      end
      if @add_tag_field and @tag_field_name.empty?
        raise ConfigError, 'tag_field_name must be set if add_tag_field is true'
      end
      if @partitioned_collection
        raise ConfigError, 'partition_key must be set in partitioned collection mode' if @partition_key.empty?
        if (@auto_create_collection &&
              @offer_throughput < AzureDocumentDB::PARTITIONED_COLL_MIN_THROUGHPUT)
          raise ConfigError, sprintf("offer_throughput must be more than and equals to %s",
                                 AzureDocumentDB::PARTITIONED_COLL_MIN_THROUGHPUT) 
        end
      end
      @timef = TimeFormatter.new(@time_format, @localtime)
    end

    def start
      super

      begin

        @client = nil
        if @partitioned_collection
          @client = AzureDocumentDB::PartitionedCollectionClient.new(@docdb_account_key,@docdb_endpoint)
        else
          @client = AzureDocumentDB::Client.new(@docdb_account_key,@docdb_endpoint)
        end

        ## initial operations for database
        res = @client.find_databases_by_name(@docdb_database)
        if( res[:body]["_count"].to_i == 0 )
          raise "No database (#{docdb_database}) exists! Enable auto_create_database or create it by useself" if !@auto_create_database 
          # create new database as it doesn't exists
          @client.create_database(@docdb_database)
        end

        ## initial operations for collection
        database_resource = @client.get_database_resource(@docdb_database)
        res = @client.find_collections_by_name(database_resource, @docdb_collection)
        if( res[:body]["_count"].to_i == 0 )
          raise "No collection (#{docdb_collection}) exists! Enable auto_create_collection or create it by useself" if !@auto_create_collection
          # create new collection as it doesn't exists
          if @partitioned_collection
            partition_key_paths = ["/#{@partition_key}"]
            @client.create_collection(database_resource,
                        @docdb_collection, partition_key_paths, @offer_throughput)
          else
            @client.create_collection(database_resource, @docdb_collection)
          end
        end
        @coll_resource = @client.get_collection_resource(database_resource, @docdb_collection)

      rescue Exception =>ex
        log.fatal "Error: '#{ex}'"
        exit!
      end
    end

    def shutdown
      super
      # destroy
    end

    def format(tag, time, record)
      record['id'] =  SecureRandom.uuid
      if @add_time_field
        record[@time_field_name] = @timef.format(time)
      end
      if @add_tag_field
        record[@tag_field_name] = tag
      end 
      record.to_msgpack
    end

    def write(chunk)
      chunk.msgpack_each { |record|
        unique_doc_identifier = record["id"]
        begin
          if @partitioned_collection
            @client.create_document(@coll_resource, unique_doc_identifier, record, @partition_key)
          else
            @client.create_document(@coll_resource, unique_doc_identifier, record)
          end
        rescue RestClient::ExceptionWithResponse => rcex
          exdict = JSON.parse(rcex.response)
          if exdict['code'] == 'Conflict'
            log.fatal "Duplicate Error: document #{unique_doc_identifier} already exists, data=>" + record.to_json
          else
            log.fatal "RestClient Error: '#{rcex.response}', data=>" + record.to_json
          end
        rescue => ex
          log.fatal "UnknownError: '#{ex}', uniqueid=>#{unique_doc_identifier}, data=>" + record.to_json
        end
      }
    end
  end
end
