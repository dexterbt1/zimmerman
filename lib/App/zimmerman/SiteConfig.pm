package App::zimmerman::SiteConfig;
use strict;
use YAML qw/Load/;

sub get_deserialized {
    my ($class, $rawdata) = @_;
    my $data = Load($rawdata);
    (ref($data) eq 'HASH')
        or die "Encountered invalid YAML data for site config";
    my $self = bless $data, $class;
    ($self->{zim} eq 'site')
        or die "Misconfigured site config";
    return $self;
}

1;

__END__

