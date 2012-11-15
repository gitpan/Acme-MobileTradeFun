use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Acme::MobileTradeFun',
    AUTHOR           => q{Satoshi Yagi <satoshi.yagi@yahoo.com>},
    VERSION_FROM     => 'lib/Acme/MobileTradeFun.pm',
    ABSTRACT_FROM    => 'lib/Acme/MobileTradeFun.pm',
    LICENSE          => 'Artistic_2_0',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'LWP::Simple'           => 0,
        'Log::Log4perl'         => 0,
        'URI::Encode'           => 0,
        'AnyEvent'              => 0,
        'AnyEvent::HTTP'        => 0,
        'Mojo::DOM'             => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES => 'Acme-MobileTradeFun-*' },
);