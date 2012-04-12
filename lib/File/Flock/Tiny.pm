package File::Flock::Tiny;

use 5.008;
use strict;
use warnings;
use Carp;
use IO::Handle;
use Fcntl qw(:flock);

=head1 NAME

File::Flock::Tiny - yet another flock package

=cut

our $VERSION = '0.11';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

    my $lock = File::Flock::Tiny->lock($file);
    ... # do something
    $lock->release;

=head1 DESCRIPTION

Simple wrapper around L<flock> for ease of use.

=head1 CLASS METHODS

=cut

sub _open_file {
    my $file = shift;
    my $fh;
    if ( ref $file && ( ref $file eq 'GLOB' || $file->isa("IO::Handle") ) ) {
        $fh = IO::Handle->new_from_fd( $file, ">>" ) or croak "Coundn't dupe file: $!";
    }
    else {
        open $fh, ">>", $file or croak "Couldn't open file: $!";
    }
    return $fh;
}

=head2 File::Flock::Tiny->lock($file)

Acquire exclusive lock on the file. I<$file> may be a file name or an opened
file handler. If a filename given and the file doesn't exist it will be
created.  The method returns a lock object, the file remains locked until this
object goes out of the scope, or till you call I<release> method on it.

=cut

sub lock {
    my $fh = _open_file( $_[1] );
    flock $fh, LOCK_EX or croak $!;
    return bless $fh, "File::Flock::Tiny::Lock";
}

=head2 File::Flock::Tiny->trylock($file)

Same as I<lock>, but if the I<$file> has been already locked, immediately
returns undef.

=cut

sub trylock {
    my $fh = _open_file( $_[1] );
    bless $fh, "File::Flock::Tiny::Lock";
    return unless flock $fh, LOCK_EX | LOCK_NB;
    return $fh;
}

=head2 File::Flock::Tiny->write_pid($file)
X<write_pid>

Try to lock the file and save the process ID into it. Returns the lock object,
or undef if the file was already locked. The lock returned by I<write_pid> will
be automatically released when the object goes out of the scope in the process
that locked the pid file, in child processes you can release the lock
explicitely.

=cut

sub write_pid {
    my ( $class, $file ) = @_;
    my $lock = $class->trylock($file);
    if ($lock) {
        $lock->truncate(0);
        $lock->print("$$\n");
        $lock->flush;
        *$lock->{destroy_only_in} = $$;
    }
    return $lock;
}

package File::Flock::Tiny::Lock;
use parent 'IO::Handle';
use Fcntl qw(:flock);

=head1 LOCK OBJECT METHODS

=head2 $lock->release

Unlock file

=cut

sub release {
    my $lock = shift;
    if ( $lock->opened ) {
        flock $lock, LOCK_UN;
        close $lock;
    }
}

sub DESTROY {
    my $lock = shift;
    unless ( *$lock->{destroy_only_in} && *$lock->{destroy_only_in} != $$ ) {
        $lock->release;
    }
}

=head2 $lock->close

Close the locked filehandle, but do not release the lock. Normally if you closed
the file it will be unlocked, but if you forked after locking the file and when
closed the lock in the parent process, the file will still be locked even after
the lock went out of the scope in the parent process. The following example
demonstrates the use for this method:

    {
        my $lock = File::Flock::Tiny->lock("lockfile");
        my $pid = fork;
        unless ( defined $pid ) {
            do_something();
        }
        $lock->close;
    }
    # file still locked by child. Without $lock->close,
    # it would be unlocked by parent when $lock went out
    # of the scope

Note, that this behaviour is not portable! It works on Linux and BSD, but on
Solaris locks are not inherited by child processes, so the file will be
unlocked as soon as the parent process will close it. See also description of
flock in L<perlfunc>.

=cut

1;

__END__

=head1 AUTHOR

Pavel Shaydo, C<< <zwon at cpan.org> >>

=head1 CAVEATS

Different implementations of flock behave differently, code that uses this
module may be non-portable, like any other code that uses flock.  See
L<perlfunc/flock> for details.

On windows you can not read the file while it is locked by another process,
hence L</write_pid> doesn't make much sense.

=head1 BUGS

Please report any bugs or feature requests via GitHub bug tracker at
L<http://github.com/trinitum/perl-File-Flock-Tiny/issues>.

=head1 SEE ALSO

A lot of modules with similar functionality on CPAN, it just happened that I
don't like any of them.


=head1 LICENSE AND COPYRIGHT

Copyright 2011, 2012 Pavel Shaydo.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut
