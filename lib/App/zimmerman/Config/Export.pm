package App::zimmerman::Config::Export;
use strict;
use YAML qw/Load DumpFile/;

sub new {
    my ($class, %p) = @_;
    my $self = bless { }, $class;
    foreach my $k (keys %p) {
        $self->{$k} = $p{$k};
    }
    if (not exists $self->{zim}) {
        $self->{zim} = 'export';
    }
    return $self;
}

sub from_file {
    my ($class, $file_name) = @_;
    open my $relfh, $file_name
        or die "Unable to open file ($file_name): $!";
    my $all_lines = join('', <$relfh>)
        or die "Unable to read file ($file_name): $!";
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
    return $self;
}

sub get_deserialized {
    my ($class, $rawdata) = @_;
    my $data = Load($rawdata);
    (ref($data) eq 'HASH')
        or die "Encountered invalid YAML data for release config";
    my $self = bless $data, $class;
    ($self->{zim} eq 'export')
        or die "Malformed config";
    return $self;
}


sub save {
    my ($self, $tmp_file_name) = @_;
    my $file_name = $tmp_file_name || $self->{file_name} || '';
    DumpFile($file_name, $self);
}


1;

__END__


