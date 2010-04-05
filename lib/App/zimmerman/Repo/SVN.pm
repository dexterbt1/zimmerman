package App::zimmerman::Repo::SVN;
use strict;
use warnings;
use base qw/App::zimmerman::Repo::_base/;
use Carp;
use File::Spec ();
use File::Basename ();
use File::Path ();
use File::Copy::Recursive ();


sub is_valid_site_name {
    my ($self, $site, $site_branch) = @_;
    my $site_name = File::Basename::basename($site);
    my $valid_name = defined($site_name) && (length $site_name>0);
    my $found = 0;
    eval {
        my $uri = $self->get_base_uri( 'svn' );
        my ($lsok, @info) = $self->run_client( 
            'ls', 
            join('', $uri->as_string, File::Spec->catdir( $site_name, $site_branch || '' ) ),
        );
        ($lsok == 0)
            or die "client error";
        $found = 1;
    };
    return $found;
}


sub get_url {
    my ($self, @p) = @_;
    my $ret = join('',
        $self->get_base_uri('svn'), 
        File::Spec->catfile(@p),
    );
    return $ret;
}
 

sub read_file {
    my ($self, %p) = @_;
    # read 
    ($self->is_valid_site_name($p{site}, $p{site_branch}))
        or croak "invalid site given site=(".$p{site}.") site_branch=(".$p{site_branch}.")";
    my $uri = $self->get_base_uri( 'svn' );
    my ($readcode, @filelines) = $self->run_client(
        'cat',
        join('', $uri->as_string, File::Spec->catfile( $p{site}, $p{site_branch} || '', $p{file_path} ) ),
    );
    ($readcode == 0)
        or die "svn client error: $readcode";
    return join('',@filelines);
}


sub export_site {
    my ($self, %p) = @_;
    ($self->is_valid_site_name($p{site}, $p{site_branch}))
        or croak "invalid site given site=(".$p{site}.") site_branch=(".$p{site_branch}.")";
    my $source = join('',
        $self->get_base_uri("svn"),
        File::Spec->catdir(
            $p{site},
            $p{site_branch} || '',
        ),
    );
    my $export_to = $p{export_to}
        or croak "Undefined export_to destination";
    my $dest = $export_to;
    (File::Spec->file_name_is_absolute($dest))
        or croak "Invalid export_to destination ($export_to), expected absolute directory ";
    if (not (-d $dest and -w $dest)) {
        File::Path::mkpath($dest);
    }
    my ($xcode, @xlines) = $self->run_client(
        'export',
        '--force',
        $source,
        $dest,
    );
    ($xcode == 0)
        or die "Failed export from [$source] to [$dest]";
    my $rev_string = pop @xlines; chomp $rev_string;
    my ($rev) = ($rev_string =~ /^Exported revision (\d+)/i);
    return $rev;
}


sub peek_site_revision {
    my ($self, %p) = @_;
    my $source = join('',
        $self->get_base_uri("svn"),
        File::Spec->catdir(
            $p{site},
            $p{site_branch} || '',
        ),
    );
    my ($peekcode, @peeklines) = $self->run_client(
        'info',
        $source,
    );
    ($peekcode == 0)
        or die "Failed peek site revision [$source]";
    my ($rev_line) = grep { /^Revision: \d+/i } @peeklines;
    chomp $rev_line;
    my ($rev) = ($rev_line =~ /^Revision: (\d+)/);
    return $rev;
}


sub run_client {
    my ($self, @p) = @_;
    my $svn = qx{which svn};
    chomp $svn;
    ($svn and -x $svn)
        or croak "Cannot find subversion client executable (svn)";
    my $cmd = join( ' ', $svn, @p );
    open my $pfh, "$cmd |"
        or croak "svn client start error";
    my @out = <$pfh>
        or die "svn client error";
    close $pfh
        or die "svn client close error: $!: $?";
    return ($?, @out);
}


1;

__END__
