package App::zimmerman::SiteConfig;
use strict;
use YAML qw/Load/;

sub new {
    my ($class, $rawdata) = @_;
    my $data = Load($rawdata);
    (ref($data) eq 'HASH')
        or die "Encountered invalid YAML data for site config";
    my $self = bless $data, $class;
    ($self->{zim})
        or die "Misconfigured site config";
    return $self;
}

1;

__END__
