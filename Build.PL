use strict;
use Module::Build;
my $build = Module::Build->new(
    module_name     => 'App::zimmerman',
    dist_author     => q{Dexter Tad-y <dtady@cpan.org>},
    license         => 'perl',
    build_requires  => {
        'perl'                      => '5.6.1',
        'ExtUtils::MakeMaker'       => '6.31',
        'File::Copy::Recursive'     => 0,
        'YAML'                      => 0,
        'URI'                       => 0,
    },
    add_to_cleanup      => [ 'Foo-Bar-*' ],
    script_files => {
        'bin/zim',
    },
);
$build->create_build_script;

