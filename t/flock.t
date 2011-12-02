use Test::More;
use strict;
use warnings;

use File::Flock::Tiny;
use File::Temp;
use Path::Class;
use Fcntl qw(:flock);
use Time::HiRes qw(usleep);
use File::Slurp;

my $dir = File::Temp->newdir;
my $file = file( $dir, 'test' );
my $content = <<EOT;
Content of this file must remain
unchanged by the end of the test.
EOT
write_file($file, $content);

sub locked {
    my $fh = $file->open(">>");
    my $locked = flock $fh, LOCK_EX | LOCK_NB;
    flock $fh, LOCK_UN;
    return ! $locked;
}

sub ok_locked {
    ok locked(), "File is locked";
}

sub ok_not_locked {
    ok !locked(), "File is not locked";
}

subtest "Basic locking by name" => sub {
    ok_not_locked;
    my $lock = File::Flock::Tiny->lock("$file");
    ok $lock,     "Got lock";
    isa_ok $lock, "File::Flock::Tiny::Lock";
    ok_locked;
    my $try = File::Flock::Tiny->trylock($file);
    ok !$try, "trylock returned false";
    $lock->release;
    ok_not_locked;
    ok( File::Flock::Tiny->trylock($file), "trylock returned true" );
    ok_not_locked;
    $lock = File::Flock::Tiny->trylock($file);
    ok_locked;
    $lock->release;
    ok_not_locked;
};

subtest "Basic locking by file handler" => sub {
    my $fh = $file->open(">>");
    {
        my $lock = File::Flock::Tiny->lock($fh);
        ok_locked;
        $lock->release;
        ok_not_locked;
    }
    ok $fh->opened, "fh is still opened";
};

subtest "Unlocking on out of scope" => sub {
    open my $fh, ">>", "$file";
    {
        ok_not_locked;
        my $lock = File::Flock::Tiny->lock($fh);
        ok_locked;
    }
    ok_not_locked;
    ok $fh->opened, "fh is still opened";
    {
        my $lock = File::Flock::Tiny->lock($file);
        ok_locked;
    }
    ok_not_locked;
};

subtest "Unlocking with fork" => sub {
    my $pid;

    {
        my $lock = File::Flock::Tiny->lock($file);
        $pid  = fork;
        if ($pid) {
            usleep(100_000);
            ok !locked, "Child unlocked file";
        }
    }
    unless ($pid) {
        exit;
    }

    {
        my $lock = File::Flock::Tiny->lock($file);
        $pid  = fork;
        if ($pid) {
            usleep(100_000);
            ok locked, "File still locked, because we closed it in child";
        }
        $lock->close;
    }
    unless ($pid) {
        exit;
    }
};

is read_file($file), $content, "File not changed";

done_testing;
