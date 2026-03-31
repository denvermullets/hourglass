# Pin npm packages by running ./bin/importmap

pin 'application'
pin '@hotwired/turbo-rails', to: 'turbo.min.js'
pin '@rails/actioncable', to: 'actioncable.esm.js'
pin '@hotwired/stimulus', to: 'stimulus.min.js'
pin '@hotwired/stimulus-loading', to: 'stimulus-loading.js'
pin_all_from 'app/javascript/controllers', under: 'controllers'

# Lexical rich text editor
pin 'lexical', to: 'https://esm.sh/lexical@0.21.0'
pin '@lexical/rich-text', to: 'https://esm.sh/@lexical/rich-text@0.21.0'
pin '@lexical/markdown', to: 'https://esm.sh/@lexical/markdown@0.21.0'
pin 'prismjs', to: 'https://esm.sh/prismjs@1.30.0'
pin '@lexical/code', to: 'https://esm.sh/@lexical/code@0.21.0'
pin '@lexical/link', to: 'https://esm.sh/@lexical/link@0.21.0'
pin '@lexical/list', to: 'https://esm.sh/@lexical/list@0.21.0'
pin '@lexical/html', to: 'https://esm.sh/@lexical/html@0.21.0'
pin '@lexical/selection', to: 'https://esm.sh/@lexical/selection@0.21.0'
pin '@lexical/utils', to: 'https://esm.sh/@lexical/utils@0.21.0'
