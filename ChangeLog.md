
## 0.3.1
* fix CVE-2020-8130 - [issue #6](https://github.com/yokawasa/fluent-plugin-documentdb/issues/6)

## 0.3.0

* Migrate to use fluentd v0.14 API - [PR#4](https://github.com/yokawasa/fluent-plugin-documentdb/pull/4)
* Support plugin specific log level - [PR#3](https://github.com/yokawasa/fluent-plugin-documentdb/pull/3) 


## 0.2.1

* Fixup bug on Single-Collection mode

## 0.2.0

* Support Partitioned Collection mode
* No longer depend on azure-documentdb-sdk instead use very tiny documentdb client library that included in the plugin

## 0.1.2
	
* Change gem package dependency option for azure-documentdb-sdk from add_development_dependency to add_dependency

## 0.1.1

* Security enhanced option: Added secret option to docdb_account_key

## 0.1.0

* Inital Release
