# [jan-sl.de](https://www.jan-sl.de)

This repository contains the code for my personal homepage. It is built with pugjs and sass.

As build tool is use brunch and a skeleton which includes the mentioned components.
See below the readme of the skeleton.

Note: although I do publish the code on GitHub, this code is not open source! Feel free to look through and get inspired for your own projects, but don't leech ;)

# Brunch + Babel/ES6 + Sass + Pug

This is a modern JS skeleton for [Brunch](http://brunch.io).

## Installation

Clone this repo

## Getting started

* Install (if you don't have them):
    * [Node.js](http://nodejs.org): `brew install node` on OS X
    * [Brunch](http://brunch.io): `npm install -g brunch`
    * Brunch plugins and app dependencies: `npm install`
* Run:
    * `brunch watch --server` — watches the project with continuous rebuild. This will also launch HTTP server with [pushState](https://developer.mozilla.org/en-US/docs/Web/Guide/API/DOM/Manipulating_the_browser_history).
    * `brunch build --production` — builds minified project for production
* Learn:
    * `public/` dir is fully auto-generated and served by HTTP server.  Write your code in `app/` dir.
    * Place static files you want to be copied from `app/assets/` to `public/`.
    * [Brunch site](http://brunch.io), [Getting started guide](https://github.com/brunch/brunch-guide#readme)

## ES7

To use proposed JS features not included into ES6, do this:

* `npm install --save-dev babel-preset-stage-0`
* in `brunch-config.js`, add the preset: `presets: ['es2015', 'stage-0']`
