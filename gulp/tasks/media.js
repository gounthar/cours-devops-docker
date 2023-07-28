/*jslint node: true */
module.exports = function (gulp, plugins, current_config) {
    'use strict';
    gulp.task('media', function () {

        var mediaFiles = gulp.src(current_config.mediaSrcPath + '/*')
            .pipe(gulp.dest(current_config.distDir + '/media/')),
            styleImages = gulp.src(current_config.stylesSrcPath + '/images/*')
            .pipe(gulp.dest(current_config.distDir + '/media/'));

        return plugins.mergeStreams(mediaFiles, styleImages)
            .pipe(plugins.browserSync.stream());
    });
};
