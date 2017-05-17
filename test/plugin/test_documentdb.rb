require 'helper'

class DocumentdbOutputTest < Test::Unit::TestCase
  def setup
    Fluent::Test.setup
  end

  CONFIG = %[
    docdb_endpoint https://yoichikademo1.documents.azure.com:443
    docdb_account_key EMwUa3EzsAtJ1qYfzwo9nQ3KudofsXNm3xLh1SLffKkUHMFl80OZRZIVu4lxdKRKxkgVAj0c2mv9BZSyMN7tdg==
    docdb_database mydb
    docdb_collection mycollection
    auto_create_database true
    auto_create_collection true
    partitioned_collection true
    partition_key host
    offer_throughput 10100
    time_format %Y%m%d-%H:%M:%S
    localtime false
    add_time_field true
    time_field_name time
    add_tag_field true
    tag_field_name tag
  ]
  # CONFIG = %[
  #   path #{TMP_DIR}/out_file_test
  #   compress gz
  #   utc
  # ]

  def create_driver(conf = CONFIG)
    Fluent::Test::Driver::Output.new(Fluent::Plugin::DocumentdbOutput).configure(conf)
  end

  def test_configure
    d = create_driver

    assert_equal 'https://yoichikademo1.documents.azure.com:443', d.instance.docdb_endpoint
    assert_equal 'EMwUa3EzsAtJ1qYfzwo9nQ3KudofsXNm3xLh1SLffKkUHMFl80OZRZIVu4lxdKRKxkgVAj0c2mv9BZSyMN7tdg==',
                 d.instance.docdb_account_key
    assert_equal 'mydb', d.instance.docdb_database
    assert_equal 'mycollection', d.instance.docdb_collection
    assert_true d.instance.auto_create_database
    assert_true d.instance.auto_create_collection
    assert_equal 'host', d.instance.partition_key
    assert_equal 10100, d.instance.offer_throughput
    assert_equal '%Y%m%d-%H:%M:%S', d.instance.time_format
    assert_false d.instance.localtime
    assert_true d.instance.add_time_field
    assert_equal 'time', d.instance.time_field_name
    assert_true d.instance.add_tag_field
    assert_equal 'tag', d.instance.tag_field_name

  end

  def test_format
    d = create_driver

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    d.run(default_tag: 'documentdb.test') do
      d.feed(time, {"a"=>1})
      d.feed(time, {"a"=>2})
    end

    # assert_equal EXPECTED1, d.formatted[0]
    # assert_equal EXPECTED2, d.formatted[1]
  end

  def test_write
    d = create_driver

    time = Time.parse("2011-01-02 13:14:15 UTC").to_i
    data = d.run(default_tag: 'documentdb.test') do
      d.feed(time, {"a"=>1})
      d.feed(time, {"a"=>2})
    end
    puts data
    # ### FileOutput#write returns path
    # path = d.run
    # expect_path = "#{TMP_DIR}/out_file_test._0.log.gz"
    # assert_equal expect_path, path
  end
end
