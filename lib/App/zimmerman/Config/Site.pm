package App::zimmerman::Config::Site;
use strict;
use YAML;
use base qw/App::zimmerman::Config::_base/;

sub type_string { 'site' }

# evaluate dependency format
sub dependencies {
    my ($self) = @_;
    my @out = ();
    if (exists $self->{dependencies}) {
        (defined $self->{dependencies})
            or die "site dependency definition cannot be null";
        (ref($self->{dependencies}) eq 'ARRAY')
            or die "site dependency definition is expected as an array";
        foreach my $df (@{$self->{dependencies}}) {
            (defined($df) and (ref($df) eq 'HASH'))
                or die "site dependency item error at: ".Dump($df);
            my ($type, $dep_info) = each %$df;
            (defined($dep_info) and (ref($dep_info) eq 'HASH'))
                or die "site dependency item definition error at: ".Dump($df);
            push @out, [ $type, $dep_info ];
        }
    }
    return @out;
}


1;

__END__

