var gulp = require('gulp'),
	sass = require('gulp-sass'),
	minifycss = require('gulp-minify-css'),
    rename = require('gulp-rename'),
    uglify = require('gulp-uglify');

var vendors = [
	'node_modules/angular/angular.min.js',
	'node_modules/angular-local-storage/dist/angular-local-storage.min.js'
];

gulp.task('styles', function() {
	return gulp.src('src/styles/*.scss')
	    .pipe(sass({ style: 'expanded' }))
	    .pipe(gulp.dest('src/styles/temp'))
	    .pipe(rename({suffix: '.min'}))
	    .pipe(minifycss())
	    .pipe(gulp.dest('extension/css'));	
});

gulp.task('compress', function() {
	return gulp.src('src/scripts/**/*.js')
		.pipe(uglify())
		.pipe(gulp.dest('extension/js'))
});

gulp.task('copy', function () {
	return gulp.src(vendors)
		.pipe(gulp.dest('extension/vendors'));
});

gulp.task('watch', function() {
	gulp.watch('src/styles/*.scss', ['styles']);
	gulp.watch('src/scripts/**/*.js', ['compress']);
});

gulp.task('default', ['watch', 'copy'], function() {
	
});