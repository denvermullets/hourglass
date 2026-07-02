# Pin npm packages by running ./bin/importmap

pin 'application'
pin '@hotwired/turbo-rails', to: 'turbo.min.js'
pin '@hotwired/stimulus', to: 'stimulus.min.js'
pin '@hotwired/stimulus-loading', to: 'stimulus-loading.js'
pin '@rails/activestorage', to: 'activestorage.esm.js'
pin_all_from 'app/javascript/controllers', under: 'controllers'
pin_all_from 'app/javascript/lexical', under: 'lexical'
pin_all_from 'app/javascript/composer', under: 'composer'

# Lexical rich text editor
# All @lexical/* packages must use ?external= to share module instances via importmap.
# Without this, each package loads its own internal copy of dependencies from esm.sh,
# causing instanceof checks (e.g., HeadingNode) to fail across packages.
pin 'lexical', to: 'https://esm.sh/lexical@0.21.0'
pin '@lexical/rich-text', to: 'https://esm.sh/@lexical/rich-text@0.21.0?external=lexical'
pin '@lexical/markdown', to: 'https://esm.sh/@lexical/markdown@0.21.0?external=lexical,@lexical/rich-text,@lexical/code,@lexical/link,@lexical/list,@lexical/utils'
pin 'prismjs', to: 'https://esm.sh/prismjs@1.30.0'
pin '@lexical/code', to: 'https://esm.sh/@lexical/code@0.21.0?external=lexical'
pin '@lexical/link', to: 'https://esm.sh/@lexical/link@0.21.0?external=lexical'
pin '@lexical/list', to: 'https://esm.sh/@lexical/list@0.21.0?external=lexical'
pin '@lexical/html', to: 'https://esm.sh/@lexical/html@0.21.0?external=lexical'
pin '@lexical/selection', to: 'https://esm.sh/@lexical/selection@0.21.0?external=lexical'
pin '@lexical/utils', to: 'https://esm.sh/@lexical/utils@0.21.0?external=lexical'
