package App::zimmerman::Repo::FS;
use strict;
use warnings;
use base qw/App::zimmerman::Repo::_base/;
use Carp;
use File::Spec;
use File::Basename;
use File::Path;
use File::Copy::Recursive;

sub is_valid_site_name {
    my ($self, $site, $site_branch) = @_;
    my $site_name = basename $site;
    my $valid_name = defined($site_name) && (length $site_name>0);
    my $found;
    eval {
        my $uri = $self->get_base_uri("file");
        (defined $uri)
            or die "invalid uri";
        my $scheme = $uri->scheme || 'file';
        ($scheme eq 'file')
            or die "invalid scheme";
        my $path = File::Spec->catdir($uri->path, $site_name, $site_branch||'');
        (-e $path && -x $path)
            or die "inaccessible";
        $found = 1;
    };
    return $valid_name && $found;
}


sub get_url {
    my ($self, @p) = @_;
    my $u = File::Spec->catfile(
        $self->get_base_uri("file")->path,
        @p,
    );
    return $u;
}


sub read_file {
    my ($self, %p) = @_;
    # read 
    ($self->is_valid_site_name($p{site}, $p{site_branch}))
        or croak "invalid site given site=(".$p{site}.") site_branch=(".$p{site_branch}.")";
    # read zim site config
    my $full_repo_path = File::Spec->catfile(
        $self->get_base_uri("file")->path,
        $p{site},
        $p{site_branch},
        $p{file_path},
    );
    open my $fh, $full_repo_path
        or croak "Unable to open site configuration ($full_repo_path)";
    my $data = join('',<$fh>)
        or croak "Unable to read site configuration ($full_repo_path)";
    return $data;
}


# returns the unique revision id
sub export_site {
    my ($self, %p) = @_;
    ($self->is_valid_site_name($p{site}, $p{site_branch}))
        or croak "invalid site given site=(".$p{site}.") site_branch=(".$p{site_branch}.")";
    my $source = File::Spec->catfile(
        $self->get_base_uri("file")->path,
        $p{site},
        $p{site_branch},
    );
    my $export_to = $p{export_to}
        or croak "Undefined export_to destination";
    my $dest = $export_to;
    (File::Spec->file_name_is_absolute($dest))
        or croak "Invalid export_to destination ($export_to), expected absolute directory ";
    if (not (-d $dest and -w $dest)) {
        mkpath $dest;
    }
    File::Copy::Recursive::rcopy( $source, $dest )
        or die "Failed Copy from [$source] to [$dest]";
    return 1; # always 1 given that later, when we try to use peek_site_revision(), the two won't match
}


sub peek_site_revision {
    return; # always return undef, given we don't have version tracking in a plain filesystem
}


1;

__END__
