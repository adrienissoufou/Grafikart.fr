user := $(shell id -u)
group := $(shell id -g)
dc := USER_ID=$(user) GROUP_ID=$(group) docker-compose
dr := $(dc) run --rm
de := docker-compose exec
drtest := $(dc) -f docker-compose.test.yml run --rm

.PHONY: help
help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: install
install: public/assets vendor/autoload.php ## Installe les différentes dépendances

.PHONY: build-docker
build-docker:
	USER_ID=$(user) GROUP_ID=$(group) docker-compose build php
	USER_ID=$(user) GROUP_ID=$(group) docker-compose build node

.PHONY: lint
lint: vendor/autoload.php ## Analyse le code
	docker run -v $(PWD):/app --rm phpstan/phpstan analyse

.PHONY: seed
seed: vendor/autoload.php ## Génère des données dans la base de données (docker-compose up doit être lancé)
	$(de) php bash -c "php bin/console doctrine:migrations:migrate -q && php bin/console hautelook:fixtures:load -q"

.PHONY: migrate
migrate: vendor/autoload.php ## Migre la base de donnée (docker-compose up doit être lancé)
	$(de) php php bin/console doctrine:migrations:migrate -q

.PHONY: import
import: vendor/autoload.php ## Import les données du site actuel
	$(dc) -f docker-compose.import.yml up -d
	# $(de) php bin/console doctrine:migrations:migrate -q
	# $(de) php bin/console app:import reset
	# $(de) php bin/console app:import users
	# $(de) php bin/console app:import tutoriels
	# $(de) php bin/console app:import blog
	$(de) php bin/console app:import comments
	# $(dc) -f docker-compose.import.yml stop

.PHONY: test
test: vendor/autoload.php ## Execute les tests
	$(drtest) php vendor/bin/phpunit
	$(dr) --no-deps node yarn run test

.PHONY: tt
tt: vendor/autoload.php ## Lance le watcher phpunit
	$(drtest) php vendor/bin/phpunit-watcher watch --filter="nothing"

.PHONY: clean
clean: ## Nettoie les containers
	$(dc) -f docker-compose.yml -f docker-compose.test.yml -f docker-compose.import.yml down --volumes

.PHONY: dev
dev: vendor/autoload.php node_modules/time ## Lance le serveur de développement
	$(dc) up

.PHONY: doc
doc: ## Génère le sommaire de la documentation
	npx doctoc ./README.md

vendor/autoload.php: composer.lock
	$(dr) --no-deps php composer install
	touch vendor/autoload.php

node_modules/time: yarn.lock
	$(dr) --no-deps node yarn
	touch node_modules/time

public/assets: node_modules/time
	$(dr) --no-deps node yarn run build
