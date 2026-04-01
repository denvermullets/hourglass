// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import { Turbo } from "@hotwired/turbo-rails"
Turbo.config.drive.prefetchEnabled = false
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
import "controllers"
