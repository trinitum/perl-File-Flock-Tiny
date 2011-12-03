use inc::Module::Install;

name     'File-Flock-Tiny';
all_from 'lib/File/Flock/Tiny.pm';
author   q{Pavel Shaydo <zwon@cpan.org>};
license  'perl';

homepage 'http://github.com/trinitum/perl-File-Flock-Tiny';
repository 'git://github.com/trinitum/perl-File-Flock-Tiny';
bugtracker 'http://github.com/trinitum/perl-File-Flock-Tiny/issues';

requires 'parent';
build_requires 'Test::More';
test_requires 'Path::Class';
test_requires 'File::Slurp';

auto_install;

WriteAll;

