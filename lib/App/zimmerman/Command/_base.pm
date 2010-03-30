package App::zimmerman::Command::_base;
use strict;
use warnings;
use Carp;
use Pod::Usage;

sub new {
    my ($class, %p) = @_;
    my $self = bless { }, $class;
    for(keys %p) { $self->{$_}=$p{$_}; }
    # require script
    ($self->{script})
        or croak "'script' param required";
    # setup
    $self->setup;
    return $self;
}

sub script { return $_[0]->{script}; }

sub setup { }

sub run {
    die "Unimplemented";
}

sub help {
    die "Unimplemented";
}

sub pod_help {
    my ($self, $source_file, $message) = @_;
    pod2usage(
        -exitval    => 2, #'NOEXIT',
        -message    => $message,
        -input      => $source_file,
        -verbose    => 1,
        -noperldoc  => 1,
    );
}

1;

__END__

UNIMPLEMENTED
