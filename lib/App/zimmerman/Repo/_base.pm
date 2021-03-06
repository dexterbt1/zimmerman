package App::zimmerman::Repo::_base;
use strict;
use warnings;
use Carp;
use URI;

sub new {
    my ($class, %p) = @_;
    my $self = bless { }, $class;
    for(keys %p) { $self->{$_}=$p{$_}; }
    # require
    ($self->{script})
        or croak "'script' param required";
    ($self->{url})
        or croak "'url' param required";
    # setup
    $self->setup;
    return $self;
}

sub script { return $_[0]->{script}; }

sub setup { }

sub get_base_uri {
    my ($self, $default_scheme) = @_;
    my $uri = URI->new($self->{url}, $default_scheme);
    return $uri;
}

sub get_url {
    croak "Unimplemented";
}

sub read_file {
    croak "Unimplemented";
}

sub export {
    croak "Unimplemented";
}

sub peek_site_revision {
    croak "Unimplemented";
}

1;

__END__
