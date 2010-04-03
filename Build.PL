use strict;
use Module::Build;
my $build = Module::Build->new(
    module_name     => 'App::zimmerman',
    dist_author     => q{Dexter B. Tad-y <dtady@cpan.org>},
    license         => 'perl',
    build_requires  => {
        'perl'                      => '5.6.1',
        'App::cpanminus'            => 0,
        'ExtUtils::MakeMaker'       => '6.31',
        'File::Copy::Recursive'     => 0,
        'YAML'                      => 0,
        'URI'                       => 0,
        'Term::Prompt'              => 0,
    },
    script_files => {
        'bin/zim',
    },
);
$build->create_build_script;

