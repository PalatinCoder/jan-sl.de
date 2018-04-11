module.exports = {
  files: {
    javascripts: {
      joinTo: {
        'vendor.js': /^(?!app)/,
        'app.js': /^app/
      }
    },
    stylesheets: {
      joinTo: {
        'main.css': /.*sass$/
      }
    }
  },

  plugins: {
    babel: {
      presets: ['es2015']
    },
    autoReload: {
      match: {
        stylesheets: ['*.css', '*.jpg', '*.png'],
        javascripts: ['*.js'],
        templates: ['*.pug']
      }
    },
    sass: {
      mode: 'native',
      options: {
        includePaths: ["node_modules/@fortawesome/fontawesome-free-webfonts/scss"]
      }
    },
    copycat: {
      "fonts": ["node_modules/@fortawesome/fontawesome-free-webfonts/webfonts"],
      verbose: true,
      onlyChanged: true
    },
    pug: {
      preCompile: true,
      staticPretty: false
    }
  },
  npm: {
    globals: {
      $: 'jquery'
    }
  },
  modules: {
    autoRequire: {
      'app.js': ['scripts/scrolldown-cta', 'scripts/landing-elements' ]
    }
  }
}
