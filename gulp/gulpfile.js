/*jslint node: true, stupid: true */

const { series, parallel, src, dest, watch } = require('gulp');
const { exec } = require('child_process');
const rename = require("gulp-rename");
const browserSync = require('browser-sync').create();
const sass = require('gulp-sass')(require('sass'));
const csso = require('gulp-csso');
const asciidoctor = require('@asciidoctor/core')();
const asciidoctorRevealjs = require('@asciidoctor/reveal.js');

asciidoctorRevealjs.register();

var current_config = {
    mediaSrcPath: '/app/content/media',
    scriptsSrcPath: '/app/assets/scripts',
    stylesSrcPath: '/app/assets/styles',
    faviconPath: '/app/content/favicon.ico',
    buildDir: process.env.BUILD_DIR || '/tmp/dist',
    sourcesDir: '/app/content',
    nodeModulesDir: '/app/node_modules',
    listen_ip: process.env.LISTEN_IP || '0.0.0.0',
    listen_port: process.env.LISTEN_PORT || 8000,
    livereload_port: process.env.LIVERELOAD_PORT || 35729,
};

function prepare_revealjs() {
    return src(current_config.nodeModulesDir + '/reveal.js/dist/**/*')
        .pipe(dest(current_config.buildDir + '/reveal.js/dist/'))
        .pipe(browserSync.stream());;
}

function prepare_revealjs_core_plugins() {
    return src(current_config.nodeModulesDir + '/reveal.js/plugin/**/*', { encoding: false })
        .pipe(dest(current_config.buildDir + '/reveal.js/plugin/'))
        .pipe(browserSync.stream());
}

function prepare_revealjs_external_plugins() {
    return src(current_config.nodeModulesDir + '/reveal.js-plugins/**/*', { encoding: false })
        .pipe(dest(current_config.buildDir + '/reveal.js/reveal.js-plugins/'))
        .pipe(browserSync.stream());
}

function prepare_revealjs_menu_plugin() {
    return src(current_config.nodeModulesDir + '/reveal.js-menu/**/*', { encoding: false })
        .pipe(dest(current_config.buildDir + '/reveal.js/reveal.js-plugins/menu/'))
        .pipe(browserSync.stream());
}

function prepare_plugin_copycode() {
    return src(current_config.nodeModulesDir + '/reveal.js-copycode/plugin/copycode/**/*', { encoding: false })
        .pipe(dest(current_config.buildDir + '/reveal.js/plugin/reveal.js-copycode/'))
        .pipe(browserSync.stream());
}

function prepare_highlightjs_min() {
    return src(current_config.nodeModulesDir + '/@highlightjs/cdn-assets/highlight.min.js')
        .pipe(dest(current_config.buildDir + '/highlightjs/'))
        .pipe(browserSync.stream());
}

function prepare_highlightjs_languages() {
    return src(current_config.nodeModulesDir + '/@highlightjs/cdn-assets/languages**/*')
        .pipe(dest(current_config.buildDir + '/highlightjs/'))
        .pipe(browserSync.stream());
}


function prepare_plugin_clipboardjs() {
    return src(current_config.nodeModulesDir + '/clipboard/dist/clipboard.min.js', { encoding: false })
        .pipe(dest(current_config.buildDir + '/scripts/'))
        .pipe(browserSync.stream());
}

function styles() {
    return src(current_config.stylesSrcPath + '/*.scss')
        .pipe(sass().on('error', sass.logError))
        .pipe(rename('build.css'))
        .pipe(csso())
        .pipe(dest(current_config.buildDir + '/styles/'))
        .pipe(browserSync.stream());
}

function html(cb) {
    const sourceFile = process.env.SOURCE_FILE || 'index.adoc';
    asciidoctor.convertFile(
        current_config.sourcesDir + '/' + sourceFile,
        {
            safe: 'unsafe',
            backend: 'revealjs',
            attributes: {
                'revealjsdir': 'node_modules/reveal.js@',
                'presentationUrl': process.env.PRESENTATION_URL,
                'repositoryUrl': process.env.REPOSITORY_URL,
            },
            to_dir: current_config.buildDir,
        }
    );
    cb();
}

function media() {
    return src(current_config.mediaSrcPath + '/*', { encoding: false })
        .pipe(dest(current_config.buildDir + '/media/'))
        .pipe(browserSync.stream());
}

function favicon() {
    return src(current_config.faviconPath, { encoding: false })
        .pipe(dest(current_config.buildDir + '/'))
        .pipe(browserSync.stream());
}

function serve(cb) {
    browserSync.init({
        server: current_config.buildDir,
        open: false,
        ui: false,
        host: current_config.listen_ip,
        port: current_config.listen_port,
    });

    cb();
}

const watchFiles = function () {
    // Watch for AsciiDoctor sources
    watch([
        current_config.sourcesDir + '/**/*.adoc', // AsciiDoctor sources
        current_config.sourcesDir + '/**/*docinfo*.html', // AsciiDoctor Docinfo files
    ], series(html));

    // Watch for media
    watch([current_config.faviconPath], series(favicon));
    watch([
        current_config.mediaSrcPath + '/*',
    ], series(media));

    // Watch Styles
    watch([
        current_config.stylesSrcPath + '/**/*.scss',
    ], series(styles));

    watch(current_config.buildDir + '/*.html').on('change', browserSync.reload);
}

function clean() {
    return exec('rm -rf ' + current_config.buildDir + '/*');
}

const build = series(
    clean,
    parallel(
        media,
        prepare_revealjs,
        prepare_revealjs_core_plugins,
        prepare_revealjs_external_plugins,
        prepare_revealjs_menu_plugin,
        prepare_plugin_copycode,
        prepare_highlightjs_min,
        prepare_highlightjs_languages,
        prepare_plugin_clipboardjs,
        favicon,
        styles,
    ),
    html,
);

exports.build = build;
exports.default = series(clean, build, serve, watchFiles)
