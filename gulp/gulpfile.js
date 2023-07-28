/*jslint node: true, stupid: true */

var tasks_dir_path = './tasks',
    fs = require('fs'),
    path = require('path'),
    gulp = require('gulp'),
    plugins = {
        asciidoctor: require('@asciidoctor/core')(),
        asciidoctorRevealjs: require('@asciidoctor/reveal.js'),
        autoprefixer: require('gulp-autoprefixer'),
        browserSync: require('browser-sync').create(),
        csso: require('gulp-csso'),
        exec: require('gulp-exec'),
        fs: require('fs'),
        mergeStreams: require('merge-stream'),
        path: require('path'),
        rename: require('gulp-rename'),
        sass: require('gulp-sass')(require('sass')),
    },
    current_config = {
        docinfosPath: '/app/content/docinfos',
        mediaSrcPath: '/app/content/media',
        scriptsSrcPath: '/app/assets/scripts',
        stylesSrcPath: '/app/assets/styles',
        fontSrcPath: '/app/assets/fonts',
        faviconPath: '/app/content/favicon.ico',
        distDir: '/app/dist',
        sourcesDir: '/app/content',
        nodeModulesDir: '/app/node_modules',
        listen_ip: process.env.LISTEN_IP || '0.0.0.0',
        listen_port: process.env.LISTEN_PORT || 8000,
        livereload_port: process.env.LIVERELOAD_PORT || 35729,
        revealjsPlugins: ["reveal.js-menu","reveal.js-toolbar"],
    };
plugins.asciidoctorRevealjs.register();

fs.readdirSync(tasks_dir_path).forEach(function (file) {
    'use strict';
    require(path.join(process.cwd(), tasks_dir_path, file))(gulp, plugins, current_config);
});


gulp.task('build', gulp.series(
    gulp.parallel(
        'fonts',
        'media',
        'videos',
        'favicon',
        'prepare:revealjs',
        'prepare:highlightjs',
        'prepare:fontawesome',
        'prepare:revealjs-plugins',
        'styles'
    ),
    'html'
));

gulp.task('default', gulp.series('clean', 'build', 'serve', 'watch'));
