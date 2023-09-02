/*jslint node: true */
module.exports = function (gulp, plugins, current_config) {
    'use strict';
    gulp.task('prepare:revealjs', function () {
        var baseRevealJSPath = current_config.nodeModulesDir + '/@asciidoctor/reveal.js/node_modules/reveal.js',
            revealJsDestDir = current_config.buildDir + '/reveal.js',
            revealJsDist = gulp.src(baseRevealJSPath + '/dist/**/*')
                .pipe(gulp.dest(revealJsDestDir + '/dist/')),
            revealJsEmbeddedPlugins = gulp.src(baseRevealJSPath + '/plugin/**/*')
                .pipe(gulp.dest(revealJsDestDir + '/plugin/')),
            revealJsCommunityPlugins = gulp.src(current_config.nodeModulesDir + '/reveal.js-plugins/**/*')
                .pipe(gulp.dest(revealJsDestDir + '/reveal.js-plugins/' )),
            revealPluginCopyCode = gulp.src(current_config.nodeModulesDir + '/reveal.js-copycode/plugin/copycode/**/*')
                .pipe(gulp.dest(current_config.buildDir + '/reveal.js/plugin/reveal.js-copycode/')),
            fontAwesomeCss = gulp.src(current_config.fontAwesomeDir + '/css/all.css')
                // https://github.com/asciidoctor/asciidoctor-reveal.js/issues/286#issuecomment-787081903
                .pipe(plugins.rename('font-awesome.css'))
                .pipe(gulp.dest(current_config.buildDir + '/styles/')),
            fontAwesomeWebfonts = gulp.src(current_config.fontAwesomeDir + '/webfonts/**/*')
                .pipe(gulp.dest(current_config.buildDir + '/webfonts/')),
            highlightJSScript = gulp.src(current_config.nodeModulesDir + '/@highlightjs/cdn-assets/highlight.min.js')
                .pipe(gulp.dest(current_config.buildDir + '/highlightjs/')),
            highlightJSLanguages = gulp.src(current_config.nodeModulesDir + '/@highlightjs/cdn-assets/languages**/*')
                .pipe(gulp.dest(current_config.buildDir + '/highlightjs/')),
            clipboardJs = gulp.src(current_config.nodeModulesDir + '/clipboard/dist/clipboard.min.js')
                .pipe(gulp.dest(current_config.buildDir + '/scripts/'))

            ;

        return plugins.mergeStreams(
            revealJsDist,
            revealJsEmbeddedPlugins,
            revealJsCommunityPlugins,
            revealPluginCopyCode,
            fontAwesomeCss,
            fontAwesomeWebfonts,
            highlightJSScript,
            highlightJSLanguages,
            clipboardJs,
        );
    });
};
