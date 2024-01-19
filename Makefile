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
rspec: .install
	@rspec

.PHONY: rspec-mysql
rspec-mysql: .install mysql-server-healthy
	@DB=mysql rspec

.PHONY: rspec-postgres
rspec-postgres: .install postgres-server-healthy
	@DB=postgres rspec

.PHONY: coverage
coverage: .install
	@COVERAGE=1 rspec

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
	@echo MySQL
	@DB=mysql rspec --format progress
	@echo PostgreSQL
	@DB=postgres rspec --format progress
	@echo SQLite
	@DB=sqlite COVERAGE=1 rspec --format progress
	@echo Rubocop
	@rubocop
	@echo Yard
	@yard

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
	@yard

.PHONY: open-doc
open-doc:
	@if [[ `which open` ]]; then open ./doc/Marj.html; fi
