package App::zimmerman::ReleaseConfig;
use strict;
use YAML qw/Load DumpFile/;

# release config files are generated after every success release.
# release config files are also updated just before symlinking.

sub new {
    my ($class, %p) = @_;
    my $self = bless { }, $class;
    foreach my $k (keys %p) {
        $self->{$k} = $p{$k};
    }
    if (not exists $self->{zim}) {
        $self->{zim} = 'release';
    }
    return $self;
}

sub from_file {
    my ($class, $file_name) = @_;
    open my $relfh, $file_name
        or die "Unable to open release config file ($file_name): $!";
    my $all_lines = join('', <$relfh>)
        or die "Unable to read release config file ($file_name): $!";
    my $href = Load($all_lines);
    my $self;
    if (ref($href) eq 'HASH') {
        $self = $class->new(%$href);
    }
    elsif (ref($href) eq __PACKAGE__) {
        $self = $href;
    }
    else {
        die "Malformed release config file ($file_name)";
    }
    $self->{file_name} = $file_name;
}

sub get_deserialized {
    my ($class, $rawdata) = @_;
    my $data = Load($rawdata);
    (ref($data) eq 'HASH')
        or die "Encountered invalid YAML data for release config";
    my $self = bless $data, $class;
    ($self->{zim} eq 'release')
        or die "Malformed release config";
    return $self;
}


sub save {
    my ($self, $tmp_file_name) = @_;
    my $file_name = $tmp_file_name || $self->{file_name} || '';
    DumpFile($file_name, $self);
}


1;

__END__

