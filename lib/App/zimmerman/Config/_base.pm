package App::zimmerman::Config::_base;
use strict;
use Carp;
use YAML qw/Load DumpFile/;

sub new {
    my ($class, %p) = @_;
    my $self = bless { }, $class;
    foreach my $k (keys %p) {
        $self->{$k} = $p{$k};
    }
    if ($self->{__loaded}) {
        ($self->type eq $self->type_string)
            or die sprintf("Malformed %s config", $self->type_string);
    }
    else {
        $self->type($self->type_string);
    }
    return $self;
}

sub from_file {
    my ($class, $file_name) = @_;
    open my $relfh, $file_name
        or die "Unable to open config file ($file_name): $!";
    my $all_lines = join('', <$relfh>)
        or die "Unable to read config file ($file_name): $!";
    my $self = $class->from_string( $all_lines );
    $self->{file_name} = $file_name;
    return $self;
}


sub from_string {
    my ($class, $raw_data) = @_;
    my $href = Load($raw_data);
    my $self;
    if (ref($href) eq 'HASH') {
        $self = $class->new(%$href, '__loaded' => 1);
    }
    elsif (ref($href) eq $class) {
        $self = $href;
    }
    else {
        die "Malformed config string";
    }
    return $self;
}


sub save {
    my ($self, $tmp_file_name) = @_;
    my $file_name = $tmp_file_name || $self->{file_name} || '';
    DumpFile($file_name, $self);
}


sub set_file_name {
    my ($self, $fn) = @_;
    ($fn)
        or croak "Invalid filename";
    $self->{file_name} = $fn;
}


sub type {
    my ($self, $v) = @_;
    if (defined $v) {
        $self->{zim} = $v;
    }
    return $self->{zim};
}

sub type_string { die "Unimplemented" }

1;

__END__


