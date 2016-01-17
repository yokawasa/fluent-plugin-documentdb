# -*- coding: utf-8 -*-

module Fluent
  class DocumentdbOutput < BufferedOutput
    Plugin.register_output('documentdb', self)

    def initialize
        super
        require 'documentdb'
        require 'msgpack'
        require 'time'
        require 'securerandom'
    end

    config_param :docdb_endpoint, :string
    config_param :docdb_account_key, :string
    config_param :docdb_database, :string
    config_param :docdb_collection, :string
    config_param :auto_create_database, :bool, :default => true
    config_param :auto_create_collection, :bool, :default => true
    config_param :time_format, :string, :default => nil
    config_param :localtime, :bool, default: false
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
            raise ConfigError, 'time_field_name is needed if add_time_field is true'
        end
        if @add_tag_field and @tag_field_name.empty?
            raise ConfigError, 'tag_field_name is needed if add_tag_field is true'
        end

        @timef = TimeFormatter.new(@time_format, @localtime)
    end

    def start
        super

        begin
            context = Azure::DocumentDB::Context.new @docdb_endpoint, @docdb_account_key

            ## initial operations for database
            database = Azure::DocumentDB::Database.new context, RestClient
            qreq = Azure::DocumentDB::QueryRequest.new "SELECT * FROM root r WHERE r.id=@id"
            qreq.parameters.add "@id", @docdb_database
            query = database.query
            qres = query.execute qreq
            if( qres[:body]["_count"].to_i == 0 )
                raise "No database (#{docdb_database}) exists! Enable auto_create_database or create it by useself" if !@auto_create_database 
                # create new database as it doesn't exists
                database.create @docdb_database
            end

            ## initial operations for collection
            collection = database.collection_for_name @docdb_database
            qreq = Azure::DocumentDB::QueryRequest.new "SELECT * FROM root r WHERE r.id=@id"
            qreq.parameters.add "@id", @docdb_collection
            query = collection.query
            qres = query.execute qreq
            if( qres[:body]["_count"].to_i == 0 )
                raise "No collection (#{docdb_collection}) exists! Enable auto_create_collection or create it by useself" if !@auto_create_collection
                # create new collection as it doesn't exists
                collection.create @docdb_collection
            end
        
            @docdb = collection.document_for_name @docdb_collection

        rescue Exception =>ex
            $log.fatal "Error: '#{ex}'"
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
        records = []
        chunk.msgpack_each { |record|
            unique_doc_identifier = record["id"]
            docdata = record.to_json
            begin
                @docdb.create unique_doc_identifier, docdata
            rescue Exception => ex
                $log.fatal "UnknownError: '#{ex}'" 
                            + ", uniqueid=>#{unique_doc_identifier}, data=>"
                            + docdata.to_s
            end
        }
    end
  end
end
