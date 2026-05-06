# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...

## Solid Cable table

The `cable` connection in `config/database.yml` shares the primary DB and sets
`schema_dump: false` (to keep the primary tables out of `db/cable_schema.rb`).
Side effect: `db:schema:load:cable` is a no-op, so `solid_cable_messages` is
**not** created by the standard setup commands. It also isn't defined as a
regular migration, so `db:migrate` won't create it on deploy.

Run this once per environment as a one-time setup (dev on first checkout,
staging/prod on first deploy of solid_cable):

```bash
bin/rails runner 'ActiveRecord::Base.establish_connection(:cable); load Rails.root.join("db/cable_schema.rb")'
```

Verify with `psql -d <db> -c '\dt solid_cable_messages'`. Without this table,
`broadcast_*_later_to` calls (used by webhook-driven Turbo broadcasts) silently
drop.
