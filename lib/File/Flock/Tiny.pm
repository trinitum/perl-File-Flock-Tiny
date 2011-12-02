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

our $VERSION = '0.01';
$VERSION = eval $VERSION;

=head1 SYNOPSIS

    my $lock = File::Flock::Tiny->lock($file);
    ... # do something
    $lock->release;

=head1 DESCRIPTION

Simple wrapper around L<flock> for ease of use.

=head1 METHODS

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

Acquire exclusive lock on file. I<$file> may be a file name or opened file
handler. If filename given and file doesn't exist it will be created.
Method returns lock object, file remains locked until this object
will go out of the scope, or till you call I<release> method on it.

=cut

sub lock {
    my $fh = _open_file( $_[1] );
    flock $fh, LOCK_EX or croak $!;
    return bless $fh, "File::Flock::Tiny::Lock";
}

=head2 File::Flock::Tiny->trylock($file)

Same as I<lock> but if I<$file> already locked immediately returns undef.

=cut

sub trylock {
    my $fh = _open_file( $_[1] );
    bless $fh, "File::Flock::Tiny::Lock";
    return unless flock $fh, LOCK_EX | LOCK_NB;
    return $fh;
}

package File::Flock::Tiny::Lock;
use parent 'IO::Handle';
use Fcntl qw(:flock);

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
    shift->release;
}

=head1 AUTHOR

Pavel Shaydo, C<< <zwon at cpan.org> >>


=head1 BUGS

Please report any bugs or feature requests via GitHub bug tracker at
L<http://github.com/trinitum/perl-File-Flock-Tiny/issues>.

=head1 SEE ALSO

A lot of modules with similar functionality on CPAN, it just happened that I
don't like any of them.


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Pavel Shaydo.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
