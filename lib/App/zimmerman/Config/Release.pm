package App::zimmerman::Config::Release;
use strict;
use base qw/App::zimmerman::Config::_base/;

sub type_string { 'release' }

sub get_release_origin {
    my ($self) = @_;
    my $out = '';
    if (exists $self->{release_origin}) {
        $out = $self->{release_origin};
    }
    return $out;
}


1;

__END__

