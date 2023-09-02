/*jslint node: true */
module.exports = function (gulp, plugins, current_config) {
    'use strict';
    gulp.task('watch', function (done) {

        // Watch for AsciiDoctor sources
        gulp.watch([
            current_config.sourcesDir + '/**/*.adoc', // AsciiDoctor sources
            current_config.sourcesDir + '/**/*docinfo*.html', // AsciiDoctor Docinfo files
        ], gulp.series('html'));

        // Watch for media
        gulp.watch([current_config.faviconPath], gulp.series('favicon'));
        gulp.watch([
            current_config.mediaSrcPath + '/*',
        ], gulp.series('media'));

        // Watch Styles and Fonts
        gulp.watch([
            current_config.stylesSrcPath + '/**/*.scss',
        ], gulp.series('styles'));

        gulp.watch(current_config.fontSrcPath + '/*', gulp.series('fonts'));

        gulp.watch("./*.html").on('change', plugins.browserSync.reload);

        return done();
    });
};
