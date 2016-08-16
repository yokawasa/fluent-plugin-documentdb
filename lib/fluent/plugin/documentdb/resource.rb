module AzureDocumentDB

  class Resource
    def initialize 
      @r = {}
    end
    protected
      attr_accessor :r
  end

  class DatabaseResource < Resource
  
    def initialize (database_rid) 
      super()
      @r['database_rid'] = database_rid
    end

    def database_rid
      @r['database_rid']
    end
  end

  class CollectionResource < Resource
  
    def initialize (database_rid, collection_rid) 
      super()
      @r['database_rid'] = database_rid
      @r['collection_rid'] = collection_rid
    end

    def database_rid
      @r['database_rid']
    end

    def collection_rid
      @r['collection_rid']
    end
  end

end
