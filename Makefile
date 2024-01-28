.install: Gemfile Gemfile.lock marj.gemspec
	@make install
	@touch .install

.PHONY: install
install:
	@bundle install

.PHONY: console
console:  .install
	@./script/console.rb

.PHONY: console-mysql
console-mysql:  .install mysql-server-healthy
	@DB=mysql ./script/console.rb

.PHONY: console-postgres
console-postgres:  .install postgres-server-healthy
	@DB=postgres ./script/console.rb

.PHONY: rspec
unit: .install
	@rspec --exclude-pattern 'spec/integration/**/*'

.PHONY: rspec
unit-sqlite: .install
	@rspec --exclude-pattern 'spec/integration/**/*'

.PHONY: rspec-mysql
unit-mysql: .install mysql-server-healthy
	@DB=mysql rspec --exclude-pattern 'spec/integration/**/*'

.PHONY: rspec-postgres
unit-postgres: .install postgres-server-healthy
	@DB=postgres rspec --exclude-pattern 'spec/integration/**/*'

.PHONY: integration
integration: .install
	@rspec spec/integration

.PHONY: coverage
coverage: .install
	@COVERAGE=1 rspec --exclude-pattern 'spec/integration/**/*'

.PHONY: rubocop
rubocop: .install
	@rubocop

.PHONY: rubocop-fix
rubocop-fix: .install
	@rubocop -A

.PHONY: precommit
precommit: mysql-server-healthy postgres-server-healthy
	@echo Install
	@bundle install
	@echo "Unit (MySQL)"
	@DB=mysql rspec --format progress --exclude-pattern 'spec/integration/**/*'
	@echo "Unit (PostgreSQL)"
	@DB=postgres rspec --format progress --exclude-pattern 'spec/integration/**/*'
	@echo "Unit (SQLite)"
	@DB=sqlite rspec --format progress --exclude-pattern 'spec/integration/**/*'
	@echo Integration
	@rspec --format progress spec/integration
	@echo Coverage
	@DB=sqlite COVERAGE=1 rspec --format progress --exclude-pattern 'spec/integration/**/*'
	@echo Rubocop
	@rubocop
	@echo Yard
	@yard --fail-on-warning
	@yard stats --list-undoc | grep '100.00% documented' > /dev/null

.PHONY: clean
clean:
	docker compose down
	rm -rf *.gem
	rm -rf .yardoc/
	rm -rf doc/
	rm -rf logs/

.PHONY: gem
gem: .install
	rm -rf *.gem
	gem build

.PHONY: mysql-logs
mysql-logs:
	@mkdir -p logs
	@touch logs/mysql-error.log
	@touch logs/mysql-general.log
	@chmod 666 logs/mysql-*.log

.PHONY: mysql-server
mysql-server:
	docker compose down
	make mysql-logs
	docker-compose up -d marj_mysql_healthy

.PHONY: mysql-server-healthy
mysql-server-healthy: mysql-logs
	@./script/docker-container-healthy marj_mysql

.PHONY: mysql-client
mysql-client:
	mysql --protocol=tcp --user=root --password=root marj

.PHONY: postgres-server
postgres-server:
	docker compose down
	docker-compose up -d marj_postgres_healthy

.PHONY: postgres-server-healthy
postgres-server-healthy: 
	@./script/docker-container-healthy marj_postgres

.PHONY: postgres-client
postgres-client:
	PGPASSWORD=root psql -h 127.0.0.1 --username root --dbname marj

.PHONY: remvove-containers
remove-containers:
	docker ps --format='{{.ID}}' | while read id; do docker kill "$$id"; done
	docker system prune -f
	docker volume ls -q | while read volume; do docker volume rm -f "$$volume"; done

.PHONY: remove-images
remove-images:
	docker images --format '{{ .Repository }}:{{ .Tag }}' | while read image; do docker rmi "$$image"; done

.PHONY: release
release:
	./script/release.rb

.PHONY: doc
doc:
	@yard --fail-on-warning

.PHONY: docs
docs: doc

.PHONY: doc-check
doc-check:
	@yard stats --list-undoc | grep '100.00% documented' > /dev/null

.PHONY: open-doc
open-doc:
	@if [[ `which open` ]]; then open ./doc/Marj.html; fi
