use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Hello::World',
    AUTHOR              => q{Dexter Tad-y <dtady@cpan.org>},
    VERSION_FROM        => 'lib/Hello/World.pm',
    ABSTRACT_FROM       => 'lib/Hello/World.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Hello-World-*' },
);
